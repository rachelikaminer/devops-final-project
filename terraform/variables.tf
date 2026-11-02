variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy, in the form owner/name"
  type        = string
}

variable "region" {
  description = "GCP region (us-central1 is eligible for the e2-micro free tier)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the VM"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Name of the VM that runs the app container"
  type        = string
  default     = "kanban-vm"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-micro"
}

variable "repository_id" {
  description = "Artifact Registry repository name for the Docker images"
  type        = string
  default     = "kanban-repo"
}

variable "ssh_source_ranges" {
  description = "IP ranges allowed to reach port 22 (narrow this to your own IP for extra security)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
