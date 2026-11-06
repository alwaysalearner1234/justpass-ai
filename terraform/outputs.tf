output "project_id" {
  description = "The GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region for regional resources"
  value       = var.region
}

# --- Artifact Registry ---
output "artifact_registry_repo_id" {
  description = "Artifact Registry Docker repository ID"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "artifact_registry_docker_url" {
  description = "Docker repository endpoint URL for tagging and pushing container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

# --- Cloud Run Backend ---
output "cloud_run_service_name" {
  description = "The Cloud Run service name"
  value       = google_cloud_run_v2_service.api.name
}

output "cloud_run_service_url" {
  description = "The direct HTTPS endpoint URL for the Cloud Run API service"
  value       = google_cloud_run_v2_service.api.uri
}

output "cloud_run_runtime_service_account" {
  description = "Email of the dedicated Cloud Run runtime service account"
  value       = google_service_account.api_runtime_sa.email
}

# --- Firebase Hosting Frontend ---
output "firebase_hosting_site_id" {
  description = "The Firebase Hosting Site ID"
  value       = google_firebase_hosting_site.default.site_id
}

output "firebase_hosting_url" {
  description = "The default public URL for Firebase Hosting frontend"
  value       = "https://${google_firebase_hosting_site.default.site_id}.web.app"
}

# --- Workload Identity Federation (GitHub Actions) ---
output "workload_identity_pool_name" {
  description = "Resource name of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.github_pool.name
}

output "workload_identity_provider" {
  description = "Full resource name of the Workload Identity Provider for GitHub Actions (use in google-github-actions/auth)"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "deployment_service_account_email" {
  description = "Email address of the dedicated deployment Service Account (use in google-github-actions/auth)"
  value       = google_service_account.github_actions_sa.email
}
