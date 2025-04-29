#!/bin/bash
set -e

echo "Installing Docker..."

# Update package index
apt-get update

# Install required packages
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index with Docker repository
apt-get update

# Install Docker Engine, containerd, and Docker Compose
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose

# Add the debian user to the docker group to enable non-root users to run docker
usermod -aG docker debian

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Verify installation
docker --version
docker compose version

echo "Docker installation completed successfully!"