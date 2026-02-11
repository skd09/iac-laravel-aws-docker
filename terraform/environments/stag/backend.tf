# =============================================================================
# Laravel AWS DevOps - STAG Terraform Backend
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "myproject-terraform-state"
    key            = "stag/terraform.tfstate"
    region         = "ca-central-1"
    encrypt        = true
    dynamodb_table = "myproject-terraform-locks"
  }
}
