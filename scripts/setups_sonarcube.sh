#!/bin/bash
set -e

# Environment variables
SONARQUBE_DOMAIN=${SONARQUBE_DOMAIN:-sonarqube.local}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-Dinner1CI4dm1n!}

echo "Installing SonarQube..."

# Create docker-compose for SonarQube
mkdir -p /opt/sonarqube
cat > /opt/sonarqube/docker-compose.yml << EOF
version: '3.8'

services:
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
    volumes:
      - sonarqube_db:/var/lib/postgresql/data
    restart: always
    networks:
      - sonarnet

  sonarqube:
    image: sonarqube:lts
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ports:
      - "9000:9000"
    restart: always
    networks:
      - sonarnet

networks:
  sonarnet:
    driver: bridge

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  sonarqube_db:
EOF

# Start SonarQube
cd /opt/sonarqube
docker compose up -d

# Update hosts file for local domain resolution
echo "127.0.0.1 ${SONARQUBE_DOMAIN}" >> /etc/hosts

# Wait for SonarQube to become available
echo "Waiting for SonarQube to become available..."
until curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
  echo "Waiting for SonarQube to start..."
  sleep 10
done

# Change default admin password
echo "Updating SonarQube admin password..."
curl -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=${ADMIN_PASSWORD}"

# Setup quality gates for different project types
cat > /opt/sonarqube/setup_quality_gates.sh << 'EOF'
#!/bin/bash

SONAR_URL="http://localhost:9000"
ADMIN_USER="admin"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"

# Create quality gate
QUALITY_GATE_ID=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/create?name=Dinner1%20Standard%20Gate" | grep -o '"id":[0-9]*' | cut -d':' -f2)

# Add conditions to quality gate
# Bugs
curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/create_condition" \
  --data-urlencode "gateId=${QUALITY_GATE_ID}" \
  --data-urlencode "metric=bugs" \
  --data-urlencode "op=GT" \
  --data-urlencode "error=0"

# Vulnerabilities
curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/create_condition" \
  --data-urlencode "gateId=${QUALITY_GATE_ID}" \
  --data-urlencode "metric=vulnerabilities" \
  --data-urlencode "op=GT" \
  --data-urlencode "error=0"

# Code Smells
curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/create_condition" \
  --data-urlencode "gateId=${QUALITY_GATE_ID}" \
  --data-urlencode "metric=code_smells" \
  --data-urlencode "op=GT" \
  --data-urlencode "error=20"

# Code Coverage
curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/create_condition" \
  --data-urlencode "gateId=${QUALITY_GATE_ID}" \
  --data-urlencode "metric=coverage" \
  --data-urlencode "op=LT" \
  --data-urlencode "error=80"

# Duplicated Lines
curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/create_condition" \
  --data-urlencode "gateId=${QUALITY_GATE_ID}" \
  --data-urlencode "metric=duplicated_lines_density" \
  --data-urlencode "op=GT" \
  --data-urlencode "error=3"

# Set as default
curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" -X POST "${SONAR_URL}/api/qualitygates/set_as_default" \
  --data-urlencode "id=${QUALITY_GATE_ID}"

echo "Quality gate 'Dinner1 Standard Gate' has been created and set as default"
EOF

chmod +x /opt/sonarqube/setup_quality_gates.sh
ADMIN_PASSWORD=${ADMIN_PASSWORD} /opt/sonarqube/setup_quality_gates.sh

# Create NGINX proxy for custom domain
apt-get install -y nginx

cat > /etc/nginx/sites-available/${SONARQUBE_DOMAIN} << EOF
server {
    listen 80;
    server_name ${SONARQUBE_DOMAIN};

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/${SONARQUBE_DOMAIN} /etc/nginx/sites-enabled/
systemctl restart nginx

echo "SonarQube installation and configuration completed!"
echo "You can access SonarQube at http://${SONARQUBE_DOMAIN}"
echo "Username: admin"
echo "Password: ${ADMIN_PASSWORD}"`