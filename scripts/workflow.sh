#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APPLICATION_DIR="${ROOT_DIR}/iac/application"
readonly IDENTITY_DIR="${ROOT_DIR}/iac/bootstrap/identity"
readonly SHARED_DIR="${ROOT_DIR}/iac/bootstrap/shared"
readonly STATE_DIR="${ROOT_DIR}/iac/bootstrap/state"

runtime_dir=""
docker_config_dir=""

log() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${runtime_dir}" && -d "${runtime_dir}" ]]; then
    rm -rf -- "${runtime_dir}"
  fi
}

trap cleanup EXIT

require_commands() {
  local command
  for command in "$@"; do
    command -v "${command}" >/dev/null 2>&1 || fail "${command} is required"
  done
}

require_environment() {
  [[ "${TARGET_ENV:-}" == "dev" ]] || fail "only the dev deployment environment may be deployed or destroyed; prod is defined but not deployed"
}

select_workspace() {
  local directory="$1"
  terraform -chdir="${directory}" workspace select -or-create "${TARGET_ENV}" >/dev/null
}

initialize_operator_outputs() {
  terraform -chdir="${SHARED_DIR}" init -input=false >/dev/null
  registry_json="$(terraform -chdir="${SHARED_DIR}" output -json container_registry)"
  vaults_json="$(terraform -chdir="${SHARED_DIR}" output -json key_vault_names)"
}

login_with_runtime_credential() {
  local purpose="$1"
  local vault_name credentials

  vault_name="$(jq -er --arg purpose "${purpose}" '.[$purpose]' <<<"${vaults_json}")"
  credentials="$(az keyvault secret show \
    --vault-name "${vault_name}" \
    --name "${TARGET_ENV}" \
    --query value \
    --output tsv \
    --only-show-errors)"

  export ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_SUBSCRIPTION_ID ARM_TENANT_ID
  ARM_CLIENT_ID="$(jq -er '.client_id' <<<"${credentials}")"
  ARM_CLIENT_SECRET="$(jq -er '.client_secret' <<<"${credentials}")"
  ARM_SUBSCRIPTION_ID="$(jq -er '.subscription_id' <<<"${credentials}")"
  ARM_TENANT_ID="$(jq -er '.tenant_id' <<<"${credentials}")"
  resource_group="$(jq -er '.resource_group' <<<"${credentials}")"
  unset credentials

  runtime_dir="$(mktemp -d "${TMPDIR:-/tmp}/novabank-workflow.XXXXXX")"
  export AZURE_CONFIG_DIR="${runtime_dir}/azure"
  export DOCKER_CONFIG="${runtime_dir}/docker"
  docker_config_dir="${runtime_dir}/docker"
  mkdir -p "${AZURE_CONFIG_DIR}" "${docker_config_dir}"
  export ARM_USE_AZUREAD=true

  az login \
    --service-principal \
    --username "${ARM_CLIENT_ID}" \
    --password "${ARM_CLIENT_SECRET}" \
    --tenant "${ARM_TENANT_ID}" \
    --output none \
    --only-show-errors
  az account set --subscription "${ARM_SUBSCRIPTION_ID}"
}

copy_buildx_plugin() {
  local candidate
  local -a candidates=(
    "${HOME}/.docker/cli-plugins/docker-buildx"
    "/Applications/Docker.app/Contents/Resources/cli-plugins/docker-buildx"
    "/opt/homebrew/lib/docker/cli-plugins/docker-buildx"
    "/usr/local/lib/docker/cli-plugins/docker-buildx"
    "/usr/libexec/docker/cli-plugins/docker-buildx"
  )

  candidate="$(command -v docker-buildx 2>/dev/null || true)"
  [[ -z "${candidate}" ]] || candidates+=("${candidate}")

  mkdir -p "${docker_config_dir}/cli-plugins"
  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      cp "${candidate}" "${docker_config_dir}/cli-plugins/docker-buildx"
      return
    fi
  done

  fail "Docker Buildx is required"
}

bootstrap() {
  require_commands az jq terraform
  [[ "${TARGET_ENV}" == "dev" || "${TARGET_ENV}" == "prod" ]] ||
    fail "ENV must be dev or prod"

  az account show --output none --only-show-errors ||
    fail "sign in with Azure CLI before running task bootstrap"

  log "Applying state bootstrap"
  terraform -chdir="${STATE_DIR}" init -input=false
  terraform -chdir="${STATE_DIR}" apply -input=false -auto-approve

  log "Applying shared bootstrap"
  terraform -chdir="${SHARED_DIR}" init -input=false
  terraform -chdir="${SHARED_DIR}" apply -input=false -auto-approve

  log "Applying ${TARGET_ENV} deployment identities"
  terraform -chdir="${IDENTITY_DIR}" init -input=false
  select_workspace "${IDENTITY_DIR}"
  terraform -chdir="${IDENTITY_DIR}" apply -input=false -auto-approve
}

wait_for_migration() {
  local job_name="$1"
  local execution_name="$2"
  local attempt status

  for attempt in {1..60}; do
    status="$(az containerapp job execution show \
      --resource-group "${resource_group}" \
      --name "${job_name}" \
      --job-execution-name "${execution_name}" \
      --query properties.status \
      --output tsv \
      --only-show-errors)"
    case "${status}" in
      Succeeded)
        log "Migration execution ${execution_name} succeeded"
        return
        ;;
      Failed)
        fail "migration execution ${execution_name} failed"
        ;;
    esac
    sleep 10
  done

  fail "migration execution ${execution_name} did not finish within 10 minutes"
}

wait_for_existing_application_secret() {
  local vault_name attempt

  vault_name="$(az keyvault list \
    --resource-group "${resource_group}" \
    --query '[0].name' \
    --output tsv \
    --only-show-errors)"
  [[ -n "${vault_name}" ]] || return

  for attempt in {1..30}; do
    if az keyvault secret show \
      --vault-name "${vault_name}" \
      --name database-url \
      --query id \
      --output none \
      --only-show-errors 2>/dev/null; then
      return
    fi
    sleep 10
  done

  fail "deployment credential could not read the existing application secret within 5 minutes"
}

deploy() {
  require_commands az docker git jq terraform
  require_environment
  initialize_operator_outputs
  login_with_runtime_credential deployment
  wait_for_existing_application_secret
  copy_buildx_plugin

  local registry_name registry_server image_tag tagged_image digest image_reference
  local job_name execution_name
  registry_name="$(jq -er '.name' <<<"${registry_json}")"
  registry_server="$(jq -er '.login_server' <<<"${registry_json}")"
  image_tag="$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD)-$(date -u +%Y%m%d%H%M%S)"
  tagged_image="${registry_server}/visit-counter:${image_tag}"

  log "Building ${tagged_image}"
  docker buildx version >/dev/null 2>&1 || fail "Docker Buildx is required"
  printf '%s' "${ARM_CLIENT_SECRET}" |
    docker login "${registry_server}" \
      --username "${ARM_CLIENT_ID}" \
      --password-stdin >/dev/null
  docker buildx build \
    --platform linux/amd64 \
    --tag "${tagged_image}" \
    --push \
    "${ROOT_DIR}"

  digest="$(az acr repository show \
    --name "${registry_name}" \
    --image "visit-counter:${image_tag}" \
    --query digest \
    --output tsv \
    --only-show-errors)"
  [[ "${digest}" == sha256:* ]] || fail "could not resolve the pushed image digest"
  image_reference="${registry_server}/visit-counter@${digest}"

  terraform -chdir="${APPLICATION_DIR}" init -input=false
  select_workspace "${APPLICATION_DIR}"

  log "Preparing private database and migration job"
  terraform -chdir="${APPLICATION_DIR}" apply \
    -input=false \
    -auto-approve \
    -var="deploy_api=false" \
    -var="image_reference=${image_reference}"

  job_name="$(terraform -chdir="${APPLICATION_DIR}" output -json migration_job | jq -er '.name')"
  execution_name="$(az containerapp job start \
    --resource-group "${resource_group}" \
    --name "${job_name}" \
    --query name \
    --output tsv \
    --only-show-errors)"
  [[ -n "${execution_name}" ]] || fail "Azure did not return a migration execution name"
  wait_for_migration "${job_name}" "${execution_name}"

  log "Deploying API by digest ${digest}"
  terraform -chdir="${APPLICATION_DIR}" apply \
    -input=false \
    -auto-approve \
    -var="deploy_api=true" \
    -var="image_reference=${image_reference}"

  terraform -chdir="${APPLICATION_DIR}" output -json application |
    jq '{name, url, image}'
}

wait_for_completion_log() {
  local workspace_id="$1"
  local correlation_id="$2"
  local query result attempt

  query="ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(15m)
| where Log_s contains '${correlation_id}'
| where Log_s contains 'request completed'
| project TimeGenerated, ContainerAppName_s, Log_s"

  for attempt in {1..30}; do
    result="$(az monitor log-analytics query \
      --workspace "${workspace_id}" \
      --analytics-query "${query}" \
      --timespan PT15M \
      --output json \
      --only-show-errors)"
    if [[ "$(jq 'length' <<<"${result}")" -gt 0 ]]; then
      jq '.[0]' <<<"${result}"
      return
    fi
    sleep 10
  done

  fail "no matching completion log found within 5 minutes"
}

smoke_test() {
  require_commands az curl jq terraform
  require_environment
  initialize_operator_outputs
  login_with_runtime_credential ai_inspection

  local app_json app_url workspace_id correlation_id
  local headers_file body_file status echoed_correlation visit_count

  app_json="$(az containerapp list \
    --resource-group "${resource_group}" \
    --query '[0].{name:name,url:properties.configuration.ingress.fqdn}' \
    --output json \
    --only-show-errors)"
  app_url="https://$(jq -er '.url' <<<"${app_json}")"
  workspace_id="$(az monitor log-analytics workspace list \
    --resource-group "${resource_group}" \
    --query '[0].customerId' \
    --output tsv \
    --only-show-errors)"
  [[ -n "${workspace_id}" ]] || fail "could not find the deployment environment's Log Analytics workspace"

  printf -v correlation_id '%04x%04x-%04x-%04x-%04x-%04x%04x%04x' \
    "${RANDOM}" "${RANDOM}" "${RANDOM}" "${RANDOM}" \
    "${RANDOM}" "${RANDOM}" "${RANDOM}" "${RANDOM}"
  headers_file="${runtime_dir}/response.headers"
  body_file="${runtime_dir}/response.json"
  status="$(curl \
    --silent \
    --show-error \
    --connect-timeout 10 \
    --max-time 30 \
    --request POST \
    --header "X-Correlation-ID: ${correlation_id}" \
    --dump-header "${headers_file}" \
    --output "${body_file}" \
    --write-out '%{http_code}' \
    "${app_url}/visits")"
  [[ "${status}" == "200" ]] || fail "POST /visits returned HTTP ${status}: $(<"${body_file}")"

  echoed_correlation="$(awk -F ': *' '
    tolower($1) == "x-correlation-id" {
      gsub("\r", "", $2)
      print $2
    }
  ' "${headers_file}" | tail -1)"
  [[ "${echoed_correlation}" == "${correlation_id}" ]] ||
    fail "visit did not echo the correlation ID"

  visit_count="$(jq -er '.count | numbers | select(. >= 1 and floor == .)' "${body_file}")"
  log "Visit accepted with visit count ${visit_count} and correlation ID ${correlation_id}"
  wait_for_completion_log "${workspace_id}" "${correlation_id}"
}

destroy() {
  require_commands az jq terraform
  require_environment
  initialize_operator_outputs
  login_with_runtime_credential deployment

  local registry_server image_reference
  registry_server="$(jq -er '.login_server' <<<"${registry_json}")"

  terraform -chdir="${APPLICATION_DIR}" init -input=false
  select_workspace "${APPLICATION_DIR}"
  image_reference="$(terraform -chdir="${APPLICATION_DIR}" output -json application 2>/dev/null |
    jq -er '.image' || true)"
  if [[ -z "${image_reference}" ]]; then
    image_reference="${registry_server}/visit-counter:bootstrap"
  fi

  terraform -chdir="${APPLICATION_DIR}" destroy \
    -input=false \
    -auto-approve \
    -var="deploy_api=true" \
    -var="image_reference=${image_reference}"
}

validate() {
  require_commands go terraform

  bash -n "${ROOT_DIR}/scripts/workflow.sh"
  terraform fmt -check -recursive "${ROOT_DIR}/iac"
  TF_WORKSPACE=dev terraform -chdir="${APPLICATION_DIR}" test \
    -filter=tests/application_stack.tftest.hcl
  TF_WORKSPACE=prod terraform -chdir="${APPLICATION_DIR}" test \
    -filter=tests/application_stack.tftest.hcl
  TF_WORKSPACE=unsupported terraform -chdir="${APPLICATION_DIR}" test \
    -filter=tests/unsupported_workspace.tftest.hcl
  TF_WORKSPACE=dev terraform -chdir="${IDENTITY_DIR}" test \
    -filter=tests/identity_bootstrap.tftest.hcl
  TF_WORKSPACE=prod terraform -chdir="${IDENTITY_DIR}" test \
    -filter=tests/identity_bootstrap.tftest.hcl
  terraform -chdir="${SHARED_DIR}" test
  terraform -chdir="${STATE_DIR}" test
  go test ./...
  go vet ./...
}

case "${1:-}" in
  bootstrap)
    bootstrap
    ;;
  deploy)
    deploy
    ;;
  test)
    smoke_test
    ;;
  destroy)
    destroy
    ;;
  validate)
    validate
    ;;
  *)
    fail "usage: workflow.sh <bootstrap|deploy|test|destroy|validate>"
    ;;
esac
