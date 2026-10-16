terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
  }
}

# Workload account: Bedrock, application inference profiles, budgets, queries.
provider "aws" {
  region  = var.region
  profile = var.workload_profile

  default_tags {
    tags = var.tags
  }
}

# Management (or Identity Center delegated admin) account.
provider "aws" {
  alias   = "management"
  region  = var.identity_center_region
  profile = var.management_profile

  default_tags {
    tags = var.tags
  }
}
