terraform {
  // Using S3 remote backend
  // Commonly used as a standard backend - A standard backend is where the Terraform state file is stored
  // remotely but the workflow is performed locally (plan/apply/destroy)
  # backend "s3" {
  #   bucket = "my-terraform-state-rcr-sample"
  #   key = "sample/aws_infra"
  #   region = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt = true
  # }
  // HTTP Option using a Basic HTTP Server
  # backend "http" {
  #   address = "http://localhost:5000/terraform_state/my_state"
  #   lock_address = "http://localhost:5000/terraform_lock/my_state"
  #   lock_method = "PUT"
  #   unlock_address = "http://localhost:5000/terraform_state/my_state"
  #   unlock_method = "DELETE"
  # }
  // Cloud option setup in Terraform cloud
  // You will either need to run Terraform cloud remotely and set your AWS access credentials as 
  // environment variables on in the workspace OR set your runs to local and only the state file will be stored
  // in the cloud
  cloud {
    organization = "PrivateWorkspace"

    workspaces {
      name = "FirstCloudWorkspaceTest"
    }
  }
  // Below is an older way to use the Terraform Cloud (Reference)
  # backend "remote" {
  #   hostname = "app.terraform.io"
  #   organization = "Enterprise-Cloud"
  #   workspaces {
  #     name = "my-aws-app"
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
  // Can set shared credentials files for apply
  # shared_credentials_files = [""]
  # profile = "default"
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = terraform.workspace
      Owner       = "Ryan Rosiak"
      Provisioned = "Terraform"
    }
  }
}