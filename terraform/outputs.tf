output "vm_name" {
  value = google_compute_instance.vm.name
}

output "zone" {
  value = var.zone
}

output "vm_external_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "image_path" {
  description = "Docker image path (without tag) for CI/CD"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}/kanban-app"
}

output "deployer_service_account" {
  description = "GitHub secret: GCP_SERVICE_ACCOUNT"
  value       = google_service_account.deployer.email
}

output "workload_identity_provider" {
  description = "GitHub secret: GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ssh_tunnel_command" {
  description = "Open the app at http://localhost:8080 after running this"
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone ${var.zone} -- -L 8080:localhost:5000"
}
