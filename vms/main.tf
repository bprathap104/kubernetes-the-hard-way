# Configure the Google Cloud provider

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

# Network Configuration
resource "google_compute_network" "kubernetes" {
  name                    = "kubernetes-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "kubernetes" {
  name          = "kubernetes-subnet"
  network       = google_compute_network.kubernetes.self_link
  ip_cidr_range = "10.240.0.0/24"
  region        = var.region
}

# Firewall Rules
resource "google_compute_firewall" "kubernetes_internal" {
  name    = "kubernetes-internal"
  network = google_compute_network.kubernetes.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.240.0.0/24"]
}

resource "google_compute_firewall" "kubernetes_external" {
  name    = "kubernetes-external"
  network = google_compute_network.kubernetes.name

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Jumpbox VM
resource "google_compute_instance" "jumpbox" {
  name         = "jumpbox"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.self_link
    access_config {} # This gives the instance a public IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  tags = ["jumpbox"]
}

# Kubernetes Control Plane
resource "google_compute_instance" "controller" {
  name         = "controller"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 200
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.self_link
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  tags = ["kubernetes", "controller"]
}

# Kubernetes Worker Nodes
resource "google_compute_instance" "workers" {
  count        = 2
  name         = "worker-${count.index}"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 200
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.self_link
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    pod-cidr = "10.200.${count.index}.0/24"
  }

  tags = ["kubernetes", "worker"]
}

# Outputs
output "jumpbox_public_ip" {
  value = google_compute_instance.jumpbox.network_interface[0].access_config[0].nat_ip
}

output "controller_public_ip" {
  value = google_compute_instance.controller.network_interface[0].access_config[0].nat_ip
}

output "worker_public_ips" {
  value = [for instance in google_compute_instance.workers : instance.network_interface[0].access_config[0].nat_ip]
}
