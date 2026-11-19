variable "aws_region" {
  description = "AWS region for all resources in this environment."
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment name (dev or prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either \"dev\" or \"prod\"."
  }
}

variable "project" {
  description = "Project name, used as the prefix in resource names (petclinic-{env}-{resource})."
  type        = string
  default     = "petclinic"
}
