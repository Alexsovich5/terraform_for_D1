# Create a Docker network for all services
resource "docker_network" "cicd_network" {
  name = "dinner1-cicd-network"
}

# Create a Docker volume for persistent data
resource "docker_volume" "gitlab_data" {
  name = "gitlab-data"
}

resource "docker_volume" "sonarqube_data" {
  name = "sonarqube-data"
}

resource "docker_volume" "sonarqube_logs" {
  name = "sonarqube-logs"
}

resource "docker_volume" "sonarqube_extensions" {
  name = "sonarqube-extensions"
}

resource "docker_volume" "sonarqube_db" {
  name = "sonarqube-db"
}

# Deploy GitLab container
resource "docker_container" "gitlab" {
  name    = "gitlab"
  image   = "gitlab/gitlab-ce:latest"
  restart = "always"

  ports {
    internal = 80
    external = 8080
  }

  ports {
    internal = 22
    external = 2222
  }

  volumes {
    container_path = "/etc/gitlab"
    volume_name    = docker_volume.gitlab_data.name
  }

  volumes {
    container_path = "/var/log/gitlab"
    host_path      = "${path.cwd}/gitlab-logs"
  }

  volumes {
    container_path = "/var/opt/gitlab"
    host_path      = "${path.cwd}/gitlab-data"
  }

  env = [
    "GITLAB_OMNIBUS_CONFIG=external_url 'http://${var.gitlab_domain}'; gitlab_rails['initial_root_password'] = '${var.admin_password}';"
  ]

  networks_advanced {
    name = docker_network.cicd_network.name
  }

  hostname = var.gitlab_domain
}

# Deploy SonarQube database container
resource "docker_container" "sonarqube_db" {
  name    = "sonarqube-db"
  image   = "postgres:13"
  restart = "always"

  env = [
    "POSTGRES_USER=sonar",
    "POSTGRES_PASSWORD=sonar",
    "POSTGRES_DB=sonar"
  ]

  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = docker_volume.sonarqube_db.name
  }

  networks_advanced {
    name = docker_network.cicd_network.name
  }
}

# Deploy SonarQube container
resource "docker_container" "sonarqube" {
  name    = "sonarqube"
  image   = "sonarqube:lts"
  restart = "always"

  depends_on = [docker_container.sonarqube_db]

  ports {
    internal = 9000
    external = 9000
  }

  env = [
    "SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonar",
    "SONAR_JDBC_USERNAME=sonar",
    "SONAR_JDBC_PASSWORD=sonar"
  ]

  volumes {
    container_path = "/opt/sonarqube/data"
    volume_name    = docker_volume.sonarqube_data.name
  }

  volumes {
    container_path = "/opt/sonarqube/extensions"
    volume_name    = docker_volume.sonarqube_extensions.name
  }

  volumes {
    container_path = "/opt/sonarqube/logs"
    volume_name    = docker_volume.sonarqube_logs.name
  }

  networks_advanced {
    name = docker_network.cicd_network.name
  }

  hostname = var.sonarqube_domain
}

# Deploy GitLab Runner container
resource "docker_container" "gitlab_runner" {
  name    = "gitlab-runner"
  image   = "gitlab/gitlab-runner:latest"
  restart = "always"

  depends_on = [docker_container.gitlab]

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }

  volumes {
    container_path = "/etc/gitlab-runner"
    host_path      = "${path.cwd}/gitlab-runner-config"
  }

  networks_advanced {
    name = docker_network.cicd_network.name
  }

  command = [
    "run",
    "--listen-address=:9252"
  ]
}
