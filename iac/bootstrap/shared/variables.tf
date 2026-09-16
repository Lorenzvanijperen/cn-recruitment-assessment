variable "location" {
  description = "Azure region for the shared resources."
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
  description = "Optional globally unique lowercase alphanumeric suffix. Defaults to a stable subscription-derived value."
  type        = string
  default     = null

  validation {
    condition     = var.name_suffix == null || can(regex("^[a-z0-9]{4,8}$", var.name_suffix))
    error_message = "name_suffix must be null or 4-8 lowercase letters or numbers."
  }
}

variable "tags" {
  description = "Tags applied to shared resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "novabank-visitor-counter"
    scope      = "shared"
  }
}
