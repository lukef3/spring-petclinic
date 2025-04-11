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
  region = var.vm_region
}

variable "gcp_project_id" {}
variable "service_account_email" {}
variable "instance_name" {}
variable "vm_region" {}
variable "vm_zone" {}
variable "machine_type" {}
variable "ssh_user" {
  default = "jenkins"
}

# VM Provisioning
resource "google_compute_instance" "docker_host" {
  project      = var.gcp_project_id
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.vm_zone
  tags         = [var.instance_name, "http-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("petclinic-jenkins-ssh.pub")}"
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

    useradd ${var.ssh_user} -m -s /bin/bash || true
    usermod -aG docker ${var.ssh_user}

    echo "Startup Script: Authenticating Docker to GCR"
    gcloud auth configure-docker gcr.io --quiet

    echo "Startup Script: Pulling PetClinic image"
    docker pull gcr.io/${var.gcp_project_id}/spring-petclinic:latest

    echo "Startup Script: Starting new PetClinic container"
    docker run -d --name spring-petclinic -p 8081:8081 --restart always gcr.io/${var.gcp_project_id}/spring-petclinic:latest
    echo "Startup Script: Finished."
  EOT

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

# Firewall Rule
resource "google_compute_firewall" "allow_access" {
  project = var.gcp_project_id
  name    = "${var.instance_name}-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8081", "22"] # Allow SSH and Application Port
  }

  target_tags   = [var.instance_name]
  source_ranges = ["0.0.0.0/0"] # Allow from anywhere
}
