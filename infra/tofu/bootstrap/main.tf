terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Bucket S3 para armazenar o state file do OpenTofu
resource "aws_s3_bucket" "tofu_state" {
  bucket = "safehire-tofu-state"

  tags = {
    Name        = "SafeHire Tofu State"
    Project     = "SafeHire AI"
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_s3_bucket_versioning" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tabela DynamoDB para lock do state
resource "aws_dynamodb_table" "tofu_locks" {
  name         = "safehire-tofu-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "SafeHire Tofu Locks"
    Project     = "SafeHire AI"
    ManagedBy   = "OpenTofu"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.tofu_state.bucket
}

output "locks_table" {
  value = aws_dynamodb_table.tofu_locks.name
}
