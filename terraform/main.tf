terraform {
  required_version = ">= 1.6"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.47"
    }
  }

  backend "s3" {
    bucket                      = "moodleshield-tfstate"
    key                         = "prod/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "https://s3.us-east-005.backblazeb2.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "deploy" {
  name       = "moodleshield-deploy"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_server" "primary" {
  name        = "moodleshield-primary"
  server_type = var.server_type
  image       = "debian-13"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.deploy.id]

  labels = {
    role = "primary"
    env  = "production"
  }
}

resource "hcloud_server" "replica" {
  name        = "moodleshield-replica"
  server_type = var.server_type
  image       = "debian-13"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.deploy.id]

  labels = {
    role = "replica"
    env  = "dr"
  }
}

resource "hcloud_network" "vpn" {
  name     = "moodleshield-vpn"
  ip_range = "10.10.0.0/16"
}

resource "hcloud_network_subnet" "vpn" {
  network_id   = hcloud_network.vpn.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.10.1.0/24"
}

resource "hcloud_server_network" "primary" {
  server_id  = hcloud_server.primary.id
  network_id = hcloud_network.vpn.id
  ip         = "10.10.1.10"

  depends_on = [hcloud_network_subnet.vpn]
}

resource "hcloud_server_network" "replica" {
  server_id  = hcloud_server.replica.id
  network_id = hcloud_network.vpn.id
  ip         = "10.10.1.11"

  depends_on = [hcloud_network_subnet.vpn]
}

resource "hcloud_firewall" "main" {
  name = "moodleshield-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_source_ips
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["10.10.0.0/16"]
  }
}

resource "hcloud_firewall_attachment" "main" {
  firewall_id = hcloud_firewall.main.id
  server_ids  = [hcloud_server.primary.id, hcloud_server.replica.id]
}

resource "hcloud_floating_ip" "primary" {
  type          = "ipv4"
  home_location = var.location
  description   = "MoodleShield primary public IP"
}

resource "hcloud_floating_ip_assignment" "primary" {
  floating_ip_id = hcloud_floating_ip.primary.id
  server_id      = var.floating_ip_target == "replica" ? hcloud_server.replica.id : hcloud_server.primary.id

  depends_on = [hcloud_server_network.primary, hcloud_server_network.replica]
}
