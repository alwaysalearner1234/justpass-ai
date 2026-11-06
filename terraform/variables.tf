variable "project_id" {
  description = "The GCP Project ID where resources will be provisioned"
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources (Cloud Run, Artifact Registry)"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment environment name (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

# --- Artifact Registry ---
variable "artifact_registry_repo_id" {
  description = "The ID of the Artifact Registry repository for container images"
  type        = string
  default     = "justpass-ai"
}

# --- Cloud Run Backend ---
variable "cloud_run_service_name" {
  description = "The name of the Cloud Run service for the backend API"
  type        = string
  default     = "justpass-api"
}

variable "cloud_run_image" {
  description = "The container image to deploy initially to Cloud Run (CI/CD will update this on each release)"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "cloud_run_port" {
  description = "Port exposed by the backend container (FastAPI listens on 8000)"
  type        = number
  default     = 8000
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run container instances (0 allows scale-to-zero)"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run container instances"
  type        = number
  default     = 10
}

variable "cloud_run_cpu" {
  description = "CPU limits for the Cloud Run instance (e.g. 1000m or 1)"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory limits for the Cloud Run instance (e.g. 512Mi or 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "database_url" {
  description = "PostgreSQL database connection string (asyncpg format)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcs_bucket_name" {
  description = "GCS bucket name for application data / homework uploads"
  type        = string
  default     = ""
}

variable "agent_url" {
  description = "URL of the agent runner service"
  type        = string
  default     = ""
}

variable "cors_allowed_origins" {
  description = "Comma-separated list of origins permitted for CORS requests to Cloud Run"
  type        = string
  default     = "*"
}

# --- Firebase Hosting ---
variable "firebase_site_id" {
  description = "Custom Firebase Hosting site ID (defaults to project_id if empty)"
  type        = string
  default     = ""
}

# --- GitHub Actions Workload Identity Federation ---
variable "github_repository" {
  description = "GitHub repository in 'owner/repo' format allowed to authenticate via WIF (e.g., voxix-dev/justpass-ai)"
  type        = string
  default     = "voxix-dev/justpass-ai"
}

variable "workload_identity_pool_id" {
  description = "ID for the Workload Identity Pool"
  type        = string
  default     = "github-actions-pool"
}

variable "workload_identity_provider_id" {
  description = "ID for the Workload Identity Pool Provider"
  type        = string
  default     = "github-provider"
}

variable "deployment_service_account_id" {
  description = "ID for the dedicated GitHub Actions deployment service account"
  type        = string
  default     = "github-actions-deployer"
}
