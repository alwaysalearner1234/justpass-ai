# Remote GCS Backend for Terraform state storage
# To initialize, run:
#   terraform init -backend-config="bucket=<YOUR_GCS_TF_STATE_BUCKET>"
terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_YOUR_GCS_TF_STATE_BUCKET"
    prefix = "justpass-ai/terraform/state"
  }
}
