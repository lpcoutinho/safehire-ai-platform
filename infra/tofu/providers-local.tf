# Provider override para desenvolvimento local (Floci)
# Este arquivo DEVE ser removido antes de deploy em staging/production
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"

  endpoints {
    s3           = "http://localhost:4566"
    dynamodb     = "http://localhost:4566"
    sts          = "http://localhost:4566"
    iam          = "http://localhost:4566"
    ecs          = "http://localhost:4566"
    rds          = "http://localhost:4566"
    elasticache  = "http://localhost:4566"
    sqs          = "http://localhost:4566"
    cloudwatch   = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    xray         = "http://localhost:4566"
    ec2          = "http://localhost:4566"
    elbv2        = "http://localhost:4566"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  default_tags {
    tags = {
      Project     = "SafeHire AI"
      Environment = "local"
      ManagedBy   = "OpenTofu"
      Repository  = "safehire-ai-platform"
    }
  }
}
