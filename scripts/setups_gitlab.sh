#!/bin/bash
set -e

# Environment variables
GITLAB_DOMAIN=${GITLAB_DOMAIN:-gitlab.local}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-Dinner1CI4dm1n!}

echo "Installing GitLab..."

# Add the GitLab package repository
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

# Install GitLab CE
EXTERNAL_URL="http://${GITLAB_DOMAIN}" apt-get install -y gitlab-ce

# Wait for GitLab to become available
echo "Waiting for GitLab to become available..."
until curl -s http://localhost/-/health > /dev/null; do
  echo "Waiting for GitLab to start..."
  sleep 10
done

# Update hosts file for local domain resolution
echo "127.0.0.1 ${GITLAB_DOMAIN}" >> /etc/hosts

# Configure GitLab
gitlab-ctl reconfigure

# Reset the root password
echo "Resetting GitLab root password..."
gitlab-rake "gitlab:password:reset[root]" << EOF
${ADMIN_PASSWORD}
${ADMIN_PASSWORD}
EOF

# Initial configuration - create a access token for API
echo "Setting up GitLab initial configuration..."

# Enable shared runners for CI/CD
gitlab-rails runner "Gitlab::CurrentSettings.current_application_settings.update_attribute(:shared_runners_enabled, true)"

# Create docker-compose for GitLab runner
cat > /opt/gitlab-runner-docker-compose.yml << EOF
version: '3.8'
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/gitlab-runner-config:/etc/gitlab-runner
    environment:
      - REGISTER_NON_INTERACTIVE=true
      - CI_SERVER_URL=http://${GITLAB_DOMAIN}
      - REGISTRATION_TOKEN=\${REGISTRATION_TOKEN}
      - RUNNER_EXECUTOR=docker
      - DOCKER_IMAGE=docker:20.10.16
      - DOCKER_VOLUMES=/var/run/docker.sock:/var/run/docker.sock
EOF

# Start the GitLab Runner
echo "Setting up GitLab Runner..."
mkdir -p /opt/gitlab-runner-config
docker compose -f /opt/gitlab-runner-docker-compose.yml up -d

echo "GitLab installation and configuration completed!"
echo "You can access GitLab at http://${GITLAB_DOMAIN}"
echo "Username: root"
echo "Password: ${ADMIN_PASSWORD}"