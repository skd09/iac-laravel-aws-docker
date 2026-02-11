# =============================================================================
# Terraform Backend Configuration
# =============================================================================

terraform {
  backend "s3" {
    bucket       = "myproject-terraform-state"
    key          = "dev/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
