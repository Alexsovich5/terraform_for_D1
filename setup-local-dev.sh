#!/bin/bash
set -e

echo "Installing development environment dependencies..."

# Update package index
sudo apt-get update

# Install Terraform
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    sudo apt-get install -y gnupg software-properties-common curl
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update
    sudo apt-get install -y terraform
else
    echo "Terraform already installed"
fi

# Install Libvirt/QEMU
echo "Installing Libvirt and QEMU..."
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager

# Enable Libvirt service
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Add current user to libvirt group
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

echo "Installation complete! You may need to log out and back in for group changes to take effect."
echo "You can now open this project in VS Code and use the Task Explorer to run Terraform commands."