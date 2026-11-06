provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

# ---------------------------------------------------------------------------------------------------------------------
# Required GCP Service APIs
# ---------------------------------------------------------------------------------------------------------------------
locals {
  required_services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com"
  ]
}

resource "google_project_service" "required_apis" {
  for_each = toset(local.required_services)
  project  = var.project_id
  service  = each.key

  disable_on_destroy         = false
  disable_dependent_services = false
}

# ---------------------------------------------------------------------------------------------------------------------
# Artifact Registry: Docker Repository
# ---------------------------------------------------------------------------------------------------------------------
resource "google_artifact_registry_repository" "docker_repo" {
  provider      = google
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo_id
  description   = "Docker container image repository for JustPass AI backend and services"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Cloud Run: Dedicated Runtime Service Account
# ---------------------------------------------------------------------------------------------------------------------
resource "google_service_account" "api_runtime_sa" {
  project      = var.project_id
  account_id   = "${var.cloud_run_service_name}-sa"
  display_name = "Cloud Run Runtime SA for ${var.cloud_run_service_name}"
  description  = "Dedicated runtime service account with minimal privileges for JustPass API Cloud Run service"
}

# ---------------------------------------------------------------------------------------------------------------------
# Cloud Run: Backend API Service (Cloud Run v2)
# ---------------------------------------------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "api" {
  provider = google
  name     = var.cloud_run_service_name
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.api_runtime_sa.email

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.cloud_run_image

      ports {
        container_port = var.cloud_run_port
      }

      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
      }

      env {
        name  = "FIREBASE_PROJECT_ID"
        value = var.project_id
      }

      dynamic "env" {
        for_each = var.database_url != "" ? [var.database_url] : []
        content {
          name  = "DATABASE_URL"
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.gcs_bucket_name != "" ? [var.gcs_bucket_name] : []
        content {
          name  = "GCS_BUCKET"
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.agent_url != "" ? [var.agent_url] : []
        content {
          name  = "AGENT_URL"
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.cors_allowed_origins != "" ? [var.cors_allowed_origins] : []
        content {
          name  = "CORS_ALLOWED_ORIGINS"
          value = env.value
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Allow CI/CD pipeline to continuously update container image without Terraform drift
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image
    ]
  }

  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.docker_repo
  ]
}

# Allow unauthenticated invocations on Cloud Run for public web API access and Firebase Hosting rewrites
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = google_cloud_run_v2_service.api.project
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------------------------------------------------
# Firebase Hosting: Project and Site Configuration (google-beta provider)
# ---------------------------------------------------------------------------------------------------------------------
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_firebase_hosting_site" "default" {
  provider = google-beta
  project  = var.project_id
  site_id  = var.firebase_site_id != "" ? var.firebase_site_id : var.project_id

  depends_on = [
    google_firebase_project.default
  ]
}
