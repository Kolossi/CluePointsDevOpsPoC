# CluePoints DevOps PoC

End-to-end CI/CD solution for deploying
[`dockersamples/helloworld-demo-python`](https://github.com/dockersamples/helloworld-demo-python)
to a managed Kubernetes cluster via GitHub Actions and Terraform.

---

## Repository structure

```
CluePointsDevOpsPoC/              # platform / template repo (this repo)
├── Dockerfile                    # multi-stage build for the app image
├── .github/
│   └── workflows/
│       ├── ci.yml                # platform self-validation (fmt, lint, validate)
│       └── pipeline.yml          # reusable pipeline (called by app repos)
├── terraform/
│   ├── modules/
│   │   └── k8s-app/              # reusable Terraform module (namespace → ingress)
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       ├── dev/                  # dev environment state & config
│       │   ├── backend.tf
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       └── prod/                 # prod environment state & config
│           ├── backend.tf
│           ├── main.tf
│           ├── variables.tf
│           └── terraform.tfvars
├── scripts/
│   └── validate.sh               # local validation helper
├── kubeconfig.yaml               # git-ignored; add your cluster credentials here
└── README.md                     # this file
```

The **app repo** (`helloworld-demo-python`) sits as a sibling directory and contains only
one added file:

```
helloworld-demo-python/
├── app.py           (existing source, untouched)
├── requirements.txt (existing, untouched)
└── .github/
    └── workflows/
        └── ci.yml   (only file added — calls reusable pipeline from this repo)
```

---

## SDLC choices

### Branching model — Trunk-based development

```
feature/my-change  ──┐
feature/other      ──┤──► main ──► (CI/CD auto-deploys to dev)
fix/bug-123        ──┘
```

- All work is done in **short-lived feature branches** (ideally < 1 day).
- A **pull request (PR)** is required to merge into `main`; PRs run the full pipeline
  (build + tests + security) but do not deploy.
- Only `main` triggers deployment to **dev** (automatic) and **prod** (manual gate).
- No long-lived environment branches — environment differences are expressed in Terraform
  variables only.

### Versioning — Semantic versioning (`MAJOR.MINOR.PATCH`)

| Component | Source | Example |
|---|---|---|
| `MAJOR` | Input in app repo `.github/workflows/ci.yml` | `1` |
| `MINOR` | Input in app repo `.github/workflows/ci.yml` | `0` |
| `PATCH` | `github.run_number` (auto-incrementing per-repo) | `42` |

Full version example: `1.0.42`

The version is:
- Used as the Docker image tag pushed to Docker Hub
- Applied as the `org.opencontainers.image.version` OCI label on the image
- Applied as a **git tag** (`v1.0.42`) on the app repo at build time

Changing MAJOR or MINOR is a deliberate act — edit the value in the app repo's
`.github/workflows/ci.yml` via a pull request.

### Promotion policy

```
PR pipeline  → build + test + security (no deploy)
main push    → build → test → security → deploy-dev (auto) → smoke-test → [approve → deploy-prod]
```

Prod deployment requires a manual approval in the GitHub Actions UI. The approver
should verify the dev deployment is healthy before approving.

### Infrastructure environment structure

Terraform environments are **separate directories** (not workspaces). Rationale:

- Separate state files prevent a mistake in one environment from affecting the other.
- Each environment has its own `terraform.tfvars` making differences explicit and
  reviewable via PR diff.
- Terraform CLI workspace approaches share a single backend config and directory,
  which is harder to lock down with per-environment RBAC and makes diffs less readable.

---

## Local development

### Prerequisites

- Docker
- Terraform >= 1.5
- `kubectl`
- A `kubeconfig.yaml` placed in the repo root (git-ignored)

### Run the app locally in a container

```bash
# From the CluePointsDevOpsPoC directory:
docker build \
  -f Dockerfile \
  -t helloworld:local \
  ../helloworld-demo-python

docker run --rm -p 8080:8080 helloworld:local
# App is available at http://localhost:8080
```

### Validate Terraform and Kubernetes manifests locally

```bash
# Ensure kubeconfig.yaml is present in the repo root, then:
./scripts/validate.sh
```

The script:
1. Validates both Terraform environments (`terraform validate`)
2. Generates a Terraform plan for dev against a placeholder image
3. Optionally runs `kubectl apply --dry-run=server` if `kubectl` is configured

---

## Infrastructure provisioning

Terraform provisions everything the app needs in each Kubernetes namespace. Nothing is
provisioned outside the namespace (the cluster itself is pre-existing and managed).

### Resources created per environment

| Resource | Kind | Notes |
|---|---|---|
| Namespace | `kubernetes_namespace` | `cluepoints-dev` or `cluepoints-prod` |
| ConfigMap | `kubernetes_config_map` | App environment variables |
| Deployment | `kubernetes_deployment` | Pulls image from Docker Hub |
| Service | `kubernetes_service` | ClusterIP, port 80 → 8080 |
| Ingress | `kubernetes_ingress_v1` | `ingressClassName: nginx`; host-based routing |

### Apply manually (dev)

```bash
export KUBECONFIG=./kubeconfig.yaml

cd terraform/environments/dev
cp backend-override.tf.example backend-override.tf
terraform init -reconfigure      # uses local state
terraform plan -var 'image=docker.io/<username>/helloworld-demo-python:latest'
terraform apply -var 'image=docker.io/<username>/helloworld-demo-python:latest'
```

### Terraform state

In CI, state is stored in **Terraform Cloud** (HCP free tier), with one CLI-driven
workspace per environment:

| Environment | Workspace |
|---|---|
| dev | `cluepoints-helloworld-dev` |
| prod | `cluepoints-helloworld-prod` |

Each workspace has independent state, run history, and access controls, preserving the
same isolation guarantees as the separate-directories design.

If your cluster already runs in a cloud provider, the equivalent native backends are a
lighter-weight alternative with no additional account required:

| Cloud | Backend | Notes |
|---|---|---|
| AWS | `s3` + DynamoDB lock | One bucket, separate state keys per env |
| GCP | `gcs` | Built-in object locking |
| Azure | `azurerm` | Built-in blob leasing |

To switch, replace the `cloud {}` block in each `backend.tf` with the appropriate
backend block and re-run `terraform init -reconfigure`.

Locally, the `backend.tf` is overridden with a `backend-override.tf` using local state
(see `backend-override.tf.example`).

---

## CI/CD pipeline

### Pipeline stages

```
build → test → security → deploy-dev → smoke-test → deploy-prod
```

| Stage | Job | Trigger | Notes |
|---|---|---|---|
| `build` | `build-image` | Every pipeline | Multi-stage docker build; push to Docker Hub; git tag |
| `test` | `unit-tests` | Every pipeline | Placeholder — add pytest invocation here |
| `security` | `security-scan` | Every pipeline | Placeholder — add Trivy / SAST here |
| `deploy-dev` | `deploy-dev` | `main` branch only | Terraform apply to `cluepoints-dev`; auto |
| `smoke-test` | `smoke-test-dev` | `main` branch only | Placeholder — add curl/health check here |
| `deploy-prod` | `deploy-prod` | `main` branch only | Terraform apply to `cluepoints-prod`; **manual** |

### Pipeline triggers

| Event | Result |
|---|---|
| Push to feature branch / PR | Build + test + security only (no deploy) |
| Merge to `main` | Full pipeline; auto-deploys to dev; prod awaits approval |
| Re-run a previous workflow on `main` | Re-deploys with same image tag |

### Approval gate

The `deploy-prod` job targets the `prod` GitHub Environment. Configure required
reviewers in the app repo under **Settings → Environments → prod → Protection rules**.
After `smoke-test-dev` passes, the workflow pauses and GitHub sends a review request
to the nominated reviewers. An authorized user clicks **Review deployments → Approve**
in the GitHub Actions workflow run page to release the deployment.

### Required GitHub Actions secrets and variables

Set these on the **app repo** as **repository** secrets/variables under
**Settings → Secrets and variables → Actions** (not environment secrets):

| Name | Kind | Where in UI | Description |
|---|---|---|---|
| `DOCKER_HUB_USERNAME` | Variable | Repository variables | Docker Hub account name — passed as workflow `input`, not secret |
| `DOCKER_HUB_TOKEN` | Secret | Repository secrets | Docker Hub access token |
| `KUBECONFIG_DATA` | Secret | Repository secrets | Base64-encoded kubeconfig: `base64 -w0 kubeconfig.yaml` — deploy jobs will fail if absent |
| `TF_TOKEN_app_terraform_io` | Secret | Repository secrets | Terraform Cloud API token — deploy jobs will fail if absent |
| `INGRESS_BASE_DOMAIN` | Variable | Repository variables | Base domain for ingress hostnames (e.g. `example.com`) |

These are repository-scoped so they are available to all jobs in the pipeline.
Environment secrets (under Settings → Environments) would only be available to
jobs targeting that specific environment, which would prevent `build-image` from
accessing them.

`GITHUB_TOKEN` is injected automatically by GitHub Actions — no setup needed.

### How the app repo calls the pipeline

The app repo's `.github/workflows/ci.yml`:

```yaml
on:
  push:
    branches: [main]
  pull_request:

jobs:
  pipeline:
    permissions:
      contents: write   # required by build-image to push the version git tag
    uses: Kolossi/CluePointsDevOpsPoC/.github/workflows/pipeline.yml@v1.0.33
    with:
      APP_VERSION_MAJOR: "1"
      APP_VERSION_MINOR: "0"
      DOCKER_HUB_USERNAME: ${{ vars.DOCKER_HUB_USERNAME }}
      INGRESS_BASE_DOMAIN: ${{ vars.INGRESS_BASE_DOMAIN }}
    secrets: inherit
```

Bumping `APP_VERSION_MAJOR` or `APP_VERSION_MINOR` via a PR is the only manual version
action required.

---

## Dev → Prod promotion

1. A merge to `main` automatically triggers the workflow.
2. The workflow builds and tags the image (`MAJOR.MINOR.github.run_number`).
3. Terraform deploys the image to `cluepoints-dev` automatically.
4. The placeholder smoke test passes.
5. An authorized team member reviews the dev deployment:
   - Verify the dev ingress URL returns HTTP 200 (see Acceptance criteria below).
   - Check application logs: `kubectl logs -n cluepoints-dev -l app=helloworld-demo-python`
6. Click **Review deployments → Approve** in the GitHub Actions workflow run page.
7. Terraform deploys the same image tag to `cluepoints-prod`.

The same immutable image tag is promoted — nothing is rebuilt for production.

---

## Rollback

### Option A — Re-run a previous workflow (preferred)

1. In GitHub → Actions → Workflows, find a previously successful run on `main`.
2. Click **Re-run jobs** and select `deploy-dev` to re-deploy that run's image to dev.
3. Verify, then approve `deploy-prod` in the same run.

This re-uses the already-published image tag without a new build.

### Option B — Terraform variable override

```bash
export KUBECONFIG=./kubeconfig.yaml
cd terraform/environments/prod
cp backend-override.tf.example backend-override.tf
terraform init -reconfigure
terraform apply -var 'image=docker.io/<username>/helloworld-demo-python:1.0.38'
```

Replace `1.0.38` with the last known-good version tag.

### Option C — Kubernetes rollout undo (emergency)

```bash
kubectl rollout undo deployment/helloworld-demo-python -n cluepoints-prod
```

Note: this bypasses Terraform state and should be followed by a proper Terraform apply to
reconcile state.

---

## Acceptance criteria

### Dev environment — "done" looks like:

```
GET http://helloworld-dev.<INGRESS_BASE_DOMAIN>/

HTTP/1.1 200 OK
Content-Type: text/html

Hello, World! (or equivalent app response)
```

Verify with:
```bash
curl -i http://helloworld-dev.<INGRESS_BASE_DOMAIN>/
```

Additional checks:
- `kubectl get pods -n cluepoints-dev` → all pods `Running`
- `kubectl get ingress -n cluepoints-dev` → ingress has an address
- GitHub Actions workflow shows all jobs green except `deploy-prod` (awaiting approval)

### Prod environment — "done" looks like:

```
GET http://helloworld-prod.<INGRESS_BASE_DOMAIN>/

HTTP/1.1 200 OK
Content-Type: text/html

Hello, World!
```

Verify with:
```bash
curl -i http://helloworld-prod.<INGRESS_BASE_DOMAIN>/
```

Additional checks:
- `kubectl get pods -n cluepoints-prod` → 2 pods `Running`
- `kubectl get ingress -n cluepoints-prod` → ingress has an address
- GitHub Actions workflow shows `deploy-prod` green with an approval timestamp

---

## Notes & assumptions

- The Kubernetes cluster is pre-existing and managed. Terraform targets only
  application-layer resources (namespace and below).
- The cluster runs the **nginx ingress controller**. All ingress resources use
  `ingressClassName: nginx`.
- The `helloworld-demo-python` app listens on port **8080**.
- `INGRESS_BASE_DOMAIN` controls the ingress hostname. For local testing,
  `127.0.0.1.nip.io` can be used as the base domain.
- `github.run_number` is monotonically increasing for the lifetime of the repository.
  It resets only if the repository is deleted and recreated.
- Placeholder test/security stages exit 0. Replace with real tooling (pytest, Trivy,
  Checkov, etc.) as the project matures.
