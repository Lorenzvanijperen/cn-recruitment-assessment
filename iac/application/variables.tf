variable "project_name" {
  description = "Short project name used in Azure resource names."
  type        = string
  default     = "novabank"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project_name))
    error_message = "project_name must be 2-20 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "name_suffix" {
  description = "Optional stable lowercase alphanumeric suffix. Defaults to a subscription-derived value."
  type        = string
  default     = null

  validation {
    condition     = var.name_suffix == null || can(regex("^[a-z0-9]{4,8}$", var.name_suffix))
    error_message = "name_suffix must be null or 4-8 lowercase letters or numbers."
  }
}

variable "image_reference" {
  description = "Optional immutable API image reference in the shared registry. Defaults to the environment YAML tag for planning."
  type        = string
  default     = null

  validation {
    condition     = var.image_reference == null ? true : length(trimspace(var.image_reference)) > 0
    error_message = "image_reference must be null or a non-empty image reference."
  }
}

variable "deploy_api" {
  description = "Whether to deploy the API. Set false while the migration job is being prepared and run."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to environment application resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "novabank-visit-counter"
    scope      = "application"
  }
}
