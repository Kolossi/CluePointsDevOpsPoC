terraform {
  cloud {
    # Organization and workspace created once at app.terraform.io.
    # Authentication: set TF_TOKEN_app_terraform_io environment variable
    # (GitHub Actions secret) — Terraform CLI picks it up automatically.
    #
    # One-time setup:
    #   1. Create a free account at app.terraform.io
    #   2. Create organisation "cluepoints"
    #   3. Create workspace "cluepoints-helloworld-prod" in CLI-driven mode
    #   4. Generate an API token and store as GitHub Secret TF_TOKEN_app_terraform_io
    #
    # For local runs, create backend-override.tf from backend-override.tf.example
    # and run: terraform init -reconfigure
    organization = "cluepoints"

    workspaces {
      name = "cluepoints-helloworld-prod"
    }
  }
}
