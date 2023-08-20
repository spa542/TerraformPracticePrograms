terraform {
  // Using S3 remote backend
  backend "s3" {
    bucket = "my-terraform-state-rcr-sample"
    key = "sample/aws_infra"
    region = "us-east-1"
  }
  // Cloud option setup in Terraform cloud
  # cloud {
  #   organization = "PrivateWorkspace"

  #   workspaces {
  #     name = "FirstCloudWorkspaceTest"
  #   }
  # }
  // For managing various providers/plugins and their version information
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.1.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = terraform.workspace
      Owner       = "Ryan Rosiak"
      Provisioned = "Terraform"
    }
  }
}