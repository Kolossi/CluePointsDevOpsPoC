#!/usr/bin/env bash
# =============================================================================
# validate.sh — local pre-flight validation for the CluePoints DevOps PoC
#
# Mirrors the checks run in .github/workflows/ci.yml so you can verify locally before
# pushing. Requires: terraform, kubectl (optional for dry-run).
#
# The terraform plan step requires Terraform Cloud credentials. Set
# TF_TOKEN_app_terraform_io to enable it; the step is skipped otherwise.
#
# Usage:
#   ./scripts/validate.sh
#
# The script expects kubeconfig.yaml in the repo root (git-ignored).
# Set KUBECONFIG manually beforehand to override:
#   KUBECONFIG=/path/to/kubeconfig ./scripts/validate.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLACEHOLDER_IMAGE="docker.io/placeholder/helloworld-demo-python:local"

# Colour helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $*"; }
fail() { echo -e "${RED}FAIL${NC}  $*"; }
info() { echo -e "${YELLOW}INFO${NC}  $*"; }

echo "======================================================================"
echo "  CluePoints DevOps PoC — local validation"
echo "======================================================================"
echo

# ---------------------------------------------------------------------------
# 0. Resolve kubeconfig
# ---------------------------------------------------------------------------
if [[ -z "${KUBECONFIG:-}" ]]; then
  KUBECONFIG_FILE="${REPO_ROOT}/kubeconfig.yaml"
  if [[ -f "${KUBECONFIG_FILE}" ]]; then
    export KUBECONFIG="${KUBECONFIG_FILE}"
    info "Using kubeconfig: ${KUBECONFIG_FILE}"
  else
    info "kubeconfig.yaml not found — kubectl dry-run will be skipped."
    info "Place kubeconfig.yaml in the repo root or set KUBECONFIG to enable it."
    SKIP_KUBECTL=true
  fi
fi
SKIP_KUBECTL=${SKIP_KUBECTL:-false}

echo

# ---------------------------------------------------------------------------
# 1. Terraform format check
# ---------------------------------------------------------------------------
info "Checking Terraform formatting..."
if terraform fmt -check -recursive "${REPO_ROOT}/terraform/" > /dev/null 2>&1; then
  pass "terraform fmt"
else
  fail "terraform fmt — run 'terraform fmt -recursive terraform/' to fix"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Terraform validate — dev
# ---------------------------------------------------------------------------
info "Validating Terraform — dev environment..."
if terraform -chdir="${REPO_ROOT}/terraform/environments/dev" init -backend=false -input=false > /dev/null 2>&1 && \
   terraform -chdir="${REPO_ROOT}/terraform/environments/dev" validate > /dev/null 2>&1; then
  pass "terraform validate (dev)"
else
  fail "terraform validate (dev)"
  terraform -chdir="${REPO_ROOT}/terraform/environments/dev" init -backend=false -input=false 2>&1 || true
  terraform -chdir="${REPO_ROOT}/terraform/environments/dev" validate 2>&1 || true
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Terraform validate — prod
# ---------------------------------------------------------------------------
info "Validating Terraform — prod environment..."
if terraform -chdir="${REPO_ROOT}/terraform/environments/prod" init -backend=false -input=false > /dev/null 2>&1 && \
   terraform -chdir="${REPO_ROOT}/terraform/environments/prod" validate > /dev/null 2>&1; then
  pass "terraform validate (prod)"
else
  fail "terraform validate (prod)"
  terraform -chdir="${REPO_ROOT}/terraform/environments/prod" init -backend=false -input=false 2>&1 || true
  terraform -chdir="${REPO_ROOT}/terraform/environments/prod" validate 2>&1 || true
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Terraform plan — dev (requires ingress_base_domain)
# ---------------------------------------------------------------------------
if [[ -z "${TF_TOKEN_app_terraform_io:-}" ]]; then
  info "TF_TOKEN_app_terraform_io not set — skipping terraform plan (requires Terraform Cloud credentials)."
  info "Set TF_TOKEN_app_terraform_io to enable the plan step locally."
else
  info "Running Terraform plan — dev (placeholder image, domain: local.example.com)..."
  DEV_DIR="${REPO_ROOT}/terraform/environments/dev"
  if terraform -chdir="${DEV_DIR}" init -input=false > /dev/null 2>&1 && \
     terraform -chdir="${DEV_DIR}" plan \
      -input=false \
      -var "image=${PLACEHOLDER_IMAGE}" \
      -var "ingress_base_domain=local.example.com" \
      -out=/dev/null > /dev/null 2>&1; then
    pass "terraform plan (dev)"
  else
    fail "terraform plan (dev) — showing output:"
    terraform -chdir="${DEV_DIR}" init -input=false 2>&1 || true
    terraform -chdir="${DEV_DIR}" plan \
      -input=false \
      -var "image=${PLACEHOLDER_IMAGE}" \
      -var "ingress_base_domain=local.example.com" 2>&1 || true
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 5. kubectl server-side dry-run (skipped if no kubeconfig)
# ---------------------------------------------------------------------------
if [[ "${SKIP_KUBECTL}" == "true" ]]; then
  info "kubectl dry-run skipped (no kubeconfig)"
else
  info "Running kubectl cluster connectivity check..."
  if kubectl cluster-info > /dev/null 2>&1; then
    pass "kubectl cluster-info"
  else
    fail "kubectl cannot reach cluster — check kubeconfig.yaml"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "======================================================================"
pass "All checks passed."
echo "======================================================================"
