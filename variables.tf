variable "vm_name" {
  description = "Name of the Debian VM"
  default     = "dinner1-cicd-test"
}

variable "vm_memory" {
  description = "Memory in MB"
  default     = 8192
}

variable "vm_vcpu" {
  description = "Number of vCPUs"
  default     = 4
}

variable "vm_disk_size" {
  description = "Disk size in bytes"
  default     = 53687091200  # 50GB
}

variable "debian_image_url" {
  description = "URL to the Debian image"
  default     = "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
}

variable "ssh_key_file" {
  description = "Path to SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_password" {
  description = "Password for admin users"
  default     = "Dinner1CI4dm1n!"
  sensitive   = true
}

variable "gitlab_domain" {
  description = "Domain for GitLab access"
  default     = "gitlab.local"
}

variable "sonarqube_domain" {
  description = "Domain for SonarQube access"
  default     = "sonarqube.local"
}