variable "project_id" {
  description = "The unique ID of your Google Cloud Project"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "europe-west3" 
}

variable "bucket_name" {
  description = "The name of the GCS bucket"
  type        = string
}

variable "dataset_id" {
  description = "The ID of the BigQuery dataset"
  type        = string
  default     = "lithium_lake_data"
}

variable "credentials_file" {
  description = "The filename of your service account JSON key"
  type        = string
  default     = "gcp-service.json" # No leading slash
}