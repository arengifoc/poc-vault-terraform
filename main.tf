# ---------------------------------------------------------
# Variables
# ---------------------------------------------------------
variable "project" {
  description = "ID del proyecto de GCP"
  type        = string
  default     = "test-preventas"
}

variable "region" {
  description = "Región de GCP"
  type        = string
  default     = "southamerica-west1"
}

variable "zone" {
  description = "Zona de GCP"
  type        = string
  default     = "southamerica-west1-a"
}

variable "network" {
  description = "Nombre de la red de GCP"
  type        = string
  default     = "demo-vpc-vault"
}

variable "subnetwork" {
  description = "Nombre de la subred de GCP"
  type        = string
  default     = "public"
}

variable "ssh_pubkey" {
  description = "Clave pública SSH para acceso a la instancia"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDw3HSUR8kuzQxufrUjYAydQ6T3TI24UcjQ2mdHMWeemLBg92c1thHlI8VMlyGhIIN3exN+VsnqRzugtoVOSoyJKEeZ5hLZxCdkQBPIaElULdB01+nLSAKU8gUxXfhzILPdrgt1IiRTScS2cUU2pCgH3lIXqgBa7Ovcb8+O1dmeuqRSEfO4Jw+Ltieya+aVn7R0QeOJkIIoMbi3zrsNnjjl5UerNnqC/ljhbIhF80y7TDn8sIcWdDzdfMshHFdix31qkk33o+0EM8EtprZ8AVZGRvJvvsuBXNcCiWMqgZWNg/kySOrEwFTtsWC7jnGjpkSkM+Y7Xjd3fNz91op4fViU/E1s3H72Ryg6nLAaD+X4+0i0nttPHqyGDqtScRXo55hfuNZphLTS8fMJ2Phxs7y9WMIfSigfO5bRZj7WTCHnnHuVILzZBoa3tDHUZHczhzF4rmzhxAAopS8gYuQ2J2SjN7zfC3DKez0YVpZfJeSsE4FwnoRrg7XaZN94g+TUuc8="
}

variable "ssh_user" {
  description = "Usuario SSH para acceso a la instancia"
  type        = string
  default     = "ubuntu"
}

variable "image" {
  description = "Imagen de GCP para la instancia"
  type        = string
  default     = "ubuntu-2404-noble-amd64-v20250502a"
}

variable "instance_name" {
  description = "Nombre de la instancia"
  type        = string
  default     = "tf-instance-ubuntu"
}

variable "machine_type" {
  description = "Tipo de máquina de GCP"
  type        = string
  default     = "e2-medium"
}

variable "instance_tags" {
  description = "Etiquetas para la instancia"
  type        = list(string)
  default     = ["ssh-server"]
}

# ---------------------------------------------------------
# Provider
# ---------------------------------------------------------
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {
    bucket  = "terraform-orion-poc-vault"
    prefix  = "terraform/state"
  }
}

# ---------------------------------------------------------
# Recursos
# ---------------------------------------------------------
resource "google_compute_instance" "default" {
  name         = var.instance_name
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = var.network
    subnetwork = "projects/${var.project}/regions/${var.region}/subnetworks/${var.subnetwork}"

    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_pubkey}"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y unzip
    wget https://releases.hashicorp.com/vault-ssh-helper/0.2.1/vault-ssh-helper_0.2.1_linux_amd64.zip
    unzip vault-ssh-helper_0.2.1_linux_amd64.zip
    sudo install vault-ssh-helper /usr/local/bin
    sudo mkdir /etc/vault-ssh-helper.d
    sudo cat > /etc/vault-ssh-helper.d/config.hcl <<EOF
    vault_addr      = "https://vault.angelrengifo.com"
    ssh_mount_point = "ssh"
    allowed_roles   = "*"
    tls_skip_verify = false
    EOF
    sudo sed -ie '/include common-auth/s/^/#/' /etc/pam.d/sshd
    sudo sed -ie '/include common-auth/aauth requisite pam_exec.so quiet expose_authtok log=\/tmp\/vaultssh.log \/usr\/local\/bin\/vault-ssh-helper -config=\/etc\/vault-ssh-helper.d\/config.hcl' /etc/pam.d/sshd
    sudo sed -ie '/vault-ssh-helper/aauth optional  pam_unix.so use_first_pass nodelay' /etc/pam.d/sshd
    sudo sed -ie '/^KbdInteractiveAuthentication/s/no/yes/' /etc/ssh/sshd_config
    echo 'ChallengeResponseAuthentication yes' | sudo tee -a /etc/ssh/sshd_config
    echo 'PasswordAuthentication no' | sudo tee -a /etc/ssh/sshd_config
    echo 'PubkeyAuthentication no' | sudo tee -a /etc/ssh/sshd_config
    sudo systemctl restart ssh
  EOT

  tags = var.instance_tags
}

resource "google_compute_firewall" "allow_internal_ssh" {
  name    = "allow-internal-ssh"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  target_tags   = var.instance_tags
  priority      = 1000
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------
output "instance_name" {
  description = "Nombre de la instancia"
  value       = google_compute_instance.default.name
}

output "instance_zone" {
  description = "Zona donde se desplegó la instancia"
  value       = google_compute_instance.default.zone
}

output "internal_ip" {
  description = "IP interna de la instancia"
  value       = google_compute_instance.default.network_interface[0].network_ip
}

output "external_ip" {
  description = "IP pública de la instancia"
  value       = google_compute_instance.default.network_interface[0].access_config[0].nat_ip
}

output "machine_type" {
  description = "Tipo de máquina (e.g., e2-medium)"
  value       = google_compute_instance.default.machine_type
}

output "boot_disk_image" {
  description = "Imagen usada para el disco de arranque"
  value       = google_compute_instance.default.boot_disk[0].initialize_params[0].image
}
