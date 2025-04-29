# Download Debian image
resource "libvirt_volume" "debian_image" {
  name   = "${var.vm_name}-debian-base"
  source = var.debian_image_url
}

# Create disk for VM
resource "libvirt_volume" "vm_disk" {
  name           = "${var.vm_name}-disk"
  base_volume_id = libvirt_volume.debian_image.id
  size           = var.vm_disk_size
}

# Read in the SSH public key
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_key_file)
}

# Cloud-init configuration for VM
resource "libvirt_cloudinit_disk" "cloud_init" {
  name      = "${var.vm_name}-cloudinit.iso"
  user_data = <<-EOF
    #cloud-config
    hostname: ${var.vm_name}
    fqdn: ${var.vm_name}.local
    manage_etc_hosts: true
    users:
      - name: debian
        sudo: ALL=(ALL) NOPASSWD:ALL
        home: /home/debian
        shell: /bin/bash
        lock_passwd: false
        ssh-authorized-keys:
          - ${trimspace(data.local_file.ssh_public_key.content)}
    packages:
      - curl
      - wget
      - gnupg
      - lsb-release
      - apt-transport-https
      - ca-certificates
      - software-properties-common
      - unzip
    runcmd:
      - echo "vm.max_map_count=262144" >> /etc/sysctl.conf
      - sysctl -p
  EOF
}

# Create the VM
resource "libvirt_domain" "dinner1_cicd_vm" {
  name   = var.vm_name
  memory = var.vm_memory
  vcpu   = var.vm_vcpu

  cloudinit = libvirt_cloudinit_disk.cloud_init.id

  disk {
    volume_id = libvirt_volume.vm_disk.id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "mkdir -p /tmp/scripts"
    ]

    connection {
      type        = "ssh"
      user        = "debian"
      host        = self.network_interface[0].addresses[0]
      private_key = file(pathexpand(replace(var.ssh_key_file, ".pub", "")))
    }
  }
}

# Install and configure Docker
module "docker" {
  source = "./modules/docker/scripts"

  vm_ip           = libvirt_domain.dinner1_cicd_vm.network_interface[0].addresses[0]
  user            = "debian"
  ssh_private_key = file(pathexpand(replace(var.ssh_key_file, ".pub", "")))

  depends_on = [libvirt_domain.dinner1_cicd_vm]
}

# Install and configure GitLab
module "gitlab" {
  source = "./modules/gitlab/scripts"

  vm_ip           = libvirt_domain.dinner1_cicd_vm.network_interface[0].addresses[0]
  user            = "debian"
  ssh_private_key = file(pathexpand(replace(var.ssh_key_file, ".pub", "")))
  gitlab_domain   = var.gitlab_domain
  admin_password  = var.admin_password

  depends_on = [module.docker]
}

# Install and configure SonarQube
module "sonarqube" {
  source = "./modules/sonarqube/scripts"

  vm_ip            = libvirt_domain.dinner1_cicd_vm.network_interface[0].addresses[0]
  user             = "debian"
  ssh_private_key  = file(pathexpand(replace(var.ssh_key_file, ".pub", "")))
  sonarqube_domain = var.sonarqube_domain
  admin_password   = var.admin_password

  depends_on = [module.docker]
}
