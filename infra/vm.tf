terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.28.0"
    }
  }
}
provider "google" {
  project = var.gcp_project_id
  region = "europe-west2"
}

variable "gcp_project_id" {}
variable "service_account_email" {}
variable "instance_name" {}

# VM Provisioning
resource "google_compute_instance" "docker_host" {
  project      = var.gcp_project_id
  name         = var.instance_name
  machine_type = "e2-small"
  zone         = "europe-west2-c"
  tags         = [var.instance_name, "http-server"] # Simple tags

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    echo "Startup Script: Updating, installing Docker & gcloud CLI..."
    apt-get update -y
    apt-get install -y docker.io

    echo "Startup Script: Installing google-cloud-cli"
    apt-get install -y google-cloud-cli

    echo "Startup Script: Starting Docker"
    systemctl start docker
    systemctl enable docker

    echo "Startup Script: Authenticating Docker to GCR"
    gcloud auth configure-docker gcr.io --quiet

    echo "Startup Script: Pulling PetClinic image"
    docker pull gcr.io/${var.gcp_project_id}/spring-petclinic:latest

    echo "Startup Script: Stopping/Removing existing container"
    docker stop spring-petclinic || true
    docker rm spring-petclinic || true

    echo "Startup Script: Starting new PetClinic container"
    docker run -d --name spring-petclinic -p 8081:8081 --restart always gcr.io/${var.gcp_project_id}/spring-petclinic:latest
    echo "Startup Script: Finished."
  EOT

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

# Firewall Rule (simplified name, targets tag from instance)
resource "google_compute_firewall" "allow_access" {
  project = var.gcp_project_id
  name    = "${var.instance_name}-allow-http" # Dynamic name based on instance
  network = "default" # Assumes default VPC

  allow {
    protocol = "tcp"
    ports    = ["8081"] # Allow SSH and App Port
  }

  # Apply rule to instances with the specified name tag
  target_tags   = [var.instance_name]
  source_ranges = ["0.0.0.0/0"] # Allow from anywhere
}
