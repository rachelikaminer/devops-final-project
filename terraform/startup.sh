#!/bin/bash
# Runs as root on every boot of the VM - every step is safe to repeat.
set -euo pipefail

# Docker
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y docker.io
fi
systemctl enable --now docker

# Let root's Docker pull from Artifact Registry using the VM's service account
HOME=/root gcloud auth configure-docker ${registry_host} --quiet

# Host folder for db.json - owned by the container's appuser (UID 10011)
mkdir -p /opt/kanban/database
chown -R 10011:10011 /opt/kanban/database
