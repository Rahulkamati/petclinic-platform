# Input variables for the vpc module.
# Spec: docs/technical-spec.md#module-vpc

variable "project" {
  description = "Project name, used as the prefix in resource names (petclinic-{env}-{resource})."
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Deployment environment name (dev or prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either \"dev\" or \"prod\"."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (dev: 10.0.0.0/16, prod: 10.1.0.0/16)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per availability zone (same order as availability_zones)."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs are required (one per AZ)."
  }

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every public_subnet_cidrs entry must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones for the public subnets. Only ap-southeast-2 AZs are allowed."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones are required."
  }

  validation {
    condition     = alltrue([for az in var.availability_zones : startswith(az, "ap-southeast-2")])
    error_message = "Only ap-southeast-2 availability zones are allowed (region is pinned by SCP)."
  }
}

variable "tags" {
  description = "Additional tags merged onto every resource (required tags come from provider default_tags)."
  type        = map(string)
  default     = {}
}
