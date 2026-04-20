terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

# create the storage bucket ("Bronze" layer for raw API data)
resource "google_storage_bucket" "lithium_lake_bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true # allows easy cleanup during development


  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30 # Automatically deletes data older than 30 days
    }
    action {
      type = "Delete"
    }
  }
}

# 2. create the BigQuery Dataset ("Silver/Gold" layer for cleaned data)
resource "google_bigquery_dataset" "lithium_lake_dataset" {
  dataset_id = var.dataset_id
  location   = var.region
  
  # This ensures that when you run 'terraform destroy', the dataset and its tables are deleted.
  delete_contents_on_destroy = true 
}