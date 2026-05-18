terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  backend "s3" {}
}

# Provider configurado via providers-local.tf (local/Floci)
# ou providers-aws.tf (staging/production)
# provider "aws" {
#   region = var.aws_region
#   default_tags {
#     tags = local.default_tags
#   }
# }
