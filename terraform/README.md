# JustPass AI: Infrastructure as Code (Terraform)

This directory contains modular Terraform configurations for provisioning the complete Google Cloud Platform (GCP) infrastructure for **JustPass AI**, including container image management, serverless backend execution, edge frontend hosting, and zero-trust GitHub Actions CI/CD authentication.

---

## 1. Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │            Firebase Hosting            │
                      │         (Global Edge Anycast)          │
                      └────┬───────────────────────────────┬───┘
                           │                               │
             Static Assets │                               │ /api/** Rewrite
             (HTML/JS/CSS) │                               │ (Same-Origin)
                           ▼                               ▼
                 ┌──────────────────┐             ┌──────────────────┐
                 │  Vite React SPA  │             │ Cloud Run API v2 │
                 │ (apps/web/dist)  │             │   (:8000 port)   │
                 └──────────────────┘             └────────┬─────────┘
                                                           │
                                        Postgres / Storage │
                                                           ▼
                                                  ┌──────────────────┐
                                                  │ Cloud SQL & GCS  │
                                                  └──────────────────┘
```

### Key Architectural Pillars:
- **Same-Origin Reverse Proxy & Zero-CORS**: Firebase Hosting serves static assets directly and transparently rewrites `/api/**` traffic to the Cloud Run backend (`justpass-api`). Browsers communicate with a single origin (`https://<project-id>.web.app`), eliminating CORS preflight latency and browser header blocking issues.
- **Defence-in-Depth CORS Support**: The FastAPI backend is configured with `CORSMiddleware` (configurable via `CORS_ALLOWED_ORIGINS`) to support direct API calls, separate preview channels, or cross-domain integrations.
- **Container Registry**: Google Artifact Registry Docker repository (`justpass-ai`) holds versioned application images.
- **Serverless API Execution**: Cloud Run v2 service runs the FastAPI backend with automated scale-to-zero capabilities, dedicated runtime service account, and custom container port mapping (`8000`).
- **Zero-Key CI/CD (Workload Identity Federation)**: GitHub Actions authenticates to GCP using short-lived OIDC tokens. No long-lived service account JSON keys are ever exported or stored in GitHub Secrets.

---

## 2. File Organization

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider version constraints (`google`, `google-beta` >= 5.20). |
| `backend.tf` | Remote GCS backend configuration for shared team state storage. |
| `variables.tf` | Comprehensive input variables with descriptions, types, and defaults. |
| `main.tf` | Core infrastructure: API enablement, Artifact Registry, Cloud Run v2, and Firebase Hosting. |
| `wif.tf` | Workload Identity Pool, GitHub OIDC Provider, Deployment SA, and least-privilege IAM bindings. |
| `outputs.tf` | Essential infrastructure endpoints, URLs, and WIF resource identifiers. |
| `terraform.tfvars.example` | Template file for environment-specific variable overrides. |

---

## 3. Prerequisites

1. **Google Cloud SDK (`gcloud`)**: Installed and authenticated (`gcloud auth login`).
2. **Terraform**: Version `>= 1.5.0` installed.
3. **GCP Project**: An active GCP Project with Billing enabled.
4. **GCS State Bucket**: A GCS bucket for remote Terraform state storage.

```bash
# Create state bucket if not already present
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export STATE_BUCKET="${PROJECT_ID}-tf-state"

gcloud storage buckets create gs://${STATE_BUCKET} --project=${PROJECT_ID} --location=${REGION} --uniform-bucket-level-access
```

---

## 4. Provisioning Step-by-Step

### Step 1: Initialize Terraform with Remote Backend

```bash
cd terraform

terraform init -backend-config="bucket=${STATE_BUCKET}"
```

### Step 2: Configure Input Variables

Copy the example variable file and fill in your project values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars`:
```hcl
project_id        = "your-gcp-project-id"
region            = "us-central1"
github_repository = "voxix-dev/justpass-ai"
```

### Step 3: Plan and Apply

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4: Retrieve Deployment Outputs

```bash
terraform output
```

You will receive:
- `workload_identity_provider`: Full resource path for GitHub Actions authentication.
- `deployment_service_account_email`: Dedicated deployer service account email.
- `artifact_registry_docker_url`: Docker repository endpoint.
- `cloud_run_service_url`: Cloud Run backend HTTPS endpoint.
- `firebase_hosting_url`: Frontend web application URL.

---

## 5. GitHub Actions Secrets & Variables Setup

Navigate to your GitHub repository (**Settings > Secrets and variables > Actions**):

### Repository Variables (or Secrets):
| Name | Value Example | Source in Terraform Output |
|---|---|---|
| `GCP_PROJECT_ID` | `your-gcp-project-id` | `project_id` |
| `GCP_REGION` | `us-central1` | `region` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider` | `workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT` | `github-actions-deployer@your-gcp-project-id.iam.gserviceaccount.com` | `deployment_service_account_email` |
| `ARTIFACT_REGISTRY_REPO` | `justpass-ai` | `artifact_registry_repo_id` |
| `CLOUD_RUN_SERVICE` | `justpass-api` | `cloud_run_service_name` |

---

## 6. Minimal Least-Privilege IAM Roles

The deployment service account (`github-actions-deployer`) is provisioned strictly with the necessary roles:
- `roles/run.admin`: Create and update Cloud Run revisions and services.
- `roles/artifactregistry.writer`: Push Docker images to GCP Artifact Registry.
- `roles/iam.serviceAccountUser`: Impersonate the dedicated Cloud Run runtime service account (`justpass-api-sa`).
- `roles/firebasehosting.admin`: Deploy new versions and releases to Firebase Hosting.
- `roles/firebase.admin`: Manage Firebase configuration.
