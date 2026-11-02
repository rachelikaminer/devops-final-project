terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ---------- APIs ----------
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ---------- Network ----------
resource "google_compute_network" "vpc" {
  name                    = "kanban-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "kanban-subnet"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}

# Only port 22 (SSH) is open. The app (port 5000) is reached through an SSH tunnel only.
resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh-only"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["kanban-vm"]
}

# ---------- Artifact Registry ----------
resource "google_artifact_registry_repository" "docker" {
  repository_id = var.repository_id
  location      = var.region
  format        = "DOCKER"
  description   = "Docker images for the Kanban app"

  depends_on = [google_project_service.apis]
}

# ---------- VM ----------
# The VM's own identity: it may only pull images from the registry
resource "google_service_account" "vm" {
  account_id   = "kanban-vm-sa"
  display_name = "Kanban VM"

  depends_on = [google_project_service.apis]
}

resource "google_artifact_registry_repository_iam_member" "vm_reader" {
  repository = google_artifact_registry_repository.docker.name
  location   = google_artifact_registry_repository.docker.location
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_compute_instance" "vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["kanban-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {} # external IP - needed for SSH
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE" # SSH access is controlled by IAM roles instead of hand-managed keys
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    registry_host = "${var.region}-docker.pkg.dev"
  })

  depends_on = [google_artifact_registry_repository_iam_member.vm_reader]
}

# ---------- GitHub Actions identity (keyless - Workload Identity Federation) ----------
resource "google_service_account" "deployer" {
  account_id   = "github-deployer"
  display_name = "GitHub Actions deployer"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Only workflows from this one repository can use this identity
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# CI: push images
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  repository = google_artifact_registry_repository.docker.name
  location   = google_artifact_registry_repository.docker.location
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

# CD: find the VM and SSH into it with sudo (OS Login)
resource "google_project_iam_member" "deployer_roles" {
  for_each = toset([
    "roles/compute.viewer",
    "roles/compute.osAdminLogin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Required to SSH into a VM that runs as a service account
resource "google_service_account_iam_member" "deployer_acts_as_vm" {
  service_account_id = google_service_account.vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}
