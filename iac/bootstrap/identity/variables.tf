variable "credential_validity" {
  description = "Validity of generated application credentials as a Terraform duration."
  type        = string
  default     = "8760h"

  validation {
    condition     = can(timeadd("2026-01-01T00:00:00Z", var.credential_validity))
    error_message = "credential_validity must be a valid Terraform duration such as 8760h."
  }
}

variable "location" {
  description = "Azure region for the environment resource-group boundary."
  type        = string
  default     = "northeurope"
}

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

variable "tags" {
  description = "Tags applied to environment-scoped Azure resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "novabank-visitor-counter"
    scope      = "environment"
  }
}
