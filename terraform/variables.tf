variable "hcloud_token" {
  description = "Hetzner Cloud API token (set via TF_VAR_hcloud_token env var)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key uploaded to Hetzner"
  type        = string
  default     = "~/.ssh/moodleshield.pub"
}

variable "server_type" {
  description = "Hetzner server type (cx22 = 2 vCPU / 4 GB RAM)"
  type        = string
  default     = "cx22"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "admin_source_ips" {
  description = "CIDR list allowed to reach SSH (restrict to your static IP)"
  type        = list(string)

  validation {
    condition     = alltrue([for ip in var.admin_source_ips : can(cidrhost(ip, 0))])
    error_message = "Each entry in admin_source_ips must be a valid CIDR block (e.g. 203.0.113.5/32)."
  }
}

variable "floating_ip_target" {
  description = "Which server receives the floating IP: 'primary' or 'replica'"
  type        = string
  default     = "primary"

  validation {
    condition     = contains(["primary", "replica"], var.floating_ip_target)
    error_message = "floating_ip_target must be 'primary' or 'replica'."
  }
}
