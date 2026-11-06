# ---------------------------------------------------------------------------------------------------------------------
# Workload Identity Federation (WIF) for GitHub Actions CI/CD
# Eliminates long-lived service account JSON keys by using short-lived OIDC tokens.
# ---------------------------------------------------------------------------------------------------------------------

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions CI/CD workflows"
  disabled                  = false

  depends_on = [
    google_project_service.required_apis
  ]
}

# Workload Identity Pool Provider (OIDC for GitHub Actions)
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = "GitHub Actions OIDC Provider"
  description                        = "OIDC identity provider connecting GitHub Actions to GCP"
  disabled                           = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Enforce least-privilege: only the designated GitHub repository can authenticate
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Dedicated Deployment Service Account
# ---------------------------------------------------------------------------------------------------------------------
resource "google_service_account" "github_actions_sa" {
  project      = var.project_id
  account_id   = var.deployment_service_account_id
  display_name = "GitHub Actions Deployment SA"
  description  = "Dedicated CI/CD service account used by GitHub Actions with minimal permissions"
}

# Allow GitHub Actions workflows in the specified repository to impersonate this service account
resource "google_service_account_iam_member" "wif_sa_impersonation" {
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}

# ---------------------------------------------------------------------------------------------------------------------
# Minimal Deployment IAM Roles (Principle of Least Privilege)
# ---------------------------------------------------------------------------------------------------------------------
locals {
  deployment_iam_roles = [
    "roles/run.admin",                  # Manage Cloud Run services and revisions
    "roles/artifactregistry.writer",   # Push Docker images to Artifact Registry
    "roles/iam.serviceAccountUser",    # Act as the Cloud Run runtime service account
    "roles/firebasehosting.admin",     # Manage Firebase Hosting releases and deploys
    "roles/firebase.admin"             # Manage Firebase project resources
  ]
}

resource "google_project_iam_member" "deployment_sa_roles" {
  for_each = toset(local.deployment_iam_roles)
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.github_actions_sa.email}"
}
