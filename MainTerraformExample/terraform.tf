terraform {
  // Not needed as this is the default, however, it does not hurt to have
  backend "local" {
    path = "terraform.tfstate"
  }
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
  // Giving an alias since we have multiple provider configurations
  alias = "east"
  default_tags {
    tags = {
      Environment = terraform.workspace
      Owner       = "Ryan Rosiak"
      Provisioned = "Terraform"
    }
  }
}

// For use cases where we want to have both east and west configurations present in the same file
provider "aws" {
  region = "us-west-2"
  // Giving an alias since we have multiple provider configurations
  alias = "west"
  default_tags {
    tags = {
      Environment = terraform.workspace
      Owner       = "Ryan Rosiak"
      Provisioned = "Terraform"
    }
  }
}
