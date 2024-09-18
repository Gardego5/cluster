terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    sops = {
      source  = "mattclegg/sops"
      version = "0.7.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }

  backend "s3" {
    bucket         = "tf-state-20230722071359242500000001"
    key            = "state/cluster"
    region         = "us-west-2"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "tf-state-20230722071359242500000001"
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "sops" {}
