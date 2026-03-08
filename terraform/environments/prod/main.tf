terraform {
  required_version = ">= 1.5"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider — kubeconfig supplied via KUBECONFIG environment variable.
# In CI: written from the KUBECONFIG_DATA base64 CI variable.
# Locally: export KUBECONFIG=../../../kubeconfig.yaml
# ---------------------------------------------------------------------------
provider "kubernetes" {
  # Reads KUBECONFIG env var automatically; no path hardcoded.
}

# ---------------------------------------------------------------------------
# Prod environment
# ---------------------------------------------------------------------------
module "app" {
  source = "../../modules/k8s-app"

  app_name     = "helloworld-demo-python"
  namespace    = "cluepoints-prod"
  image        = var.image
  replicas     = 2
  ingress_host = "helloworld-prod.${var.ingress_base_domain}"
  log_level    = "INFO"
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "namespace" {
  value = module.app.namespace
}

output "ingress_url" {
  value = "http://${module.app.ingress_host}/"
}
