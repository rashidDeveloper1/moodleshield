# Deployment Guide

## Prerequisites

| Tool        | Version  |
|-------------|----------|
| Terraform   | ≥ 1.6    |
| Ansible     | ≥ 2.16   |
| Python      | ≥ 3.11   |

## 1 — Generate SSH key pair

```bash
ssh-keygen -t ed25519 -f ~/.ssh/moodleshield -C "moodleshield-deploy"
```

## 2 — Create Ansible Vault file

```bash
ansible-vault create ansible/group_vars/vault.yml
```

Add these keys (replace placeholders):

```yaml
vault_moodle_admin_pass: <strong-password>
vault_pg_pass:           <strong-password>
vault_redis_pass:        <strong-password>
vault_restic_password:   <strong-password>
vault_b2_account_id:     <backblaze-account-id>
vault_b2_account_key:    <backblaze-application-key>
vault_wg_server_private_key: <output-of-wg-genkey>
```

## 3 — Set Terraform variables

```bash
export TF_VAR_hcloud_token="<hetzner-api-token>"
export TF_VAR_admin_source_ips='["<your-static-ip>/32"]'
```

## 4 — Run full provisioning

```bash
bash scripts/install/provision.sh
```

This will:
1. Provision two Hetzner servers via Terraform
2. Write their IPs into the Ansible inventory
3. Run the full Ansible playbook (base → postgres → php → redis → nginx → tls → moodle → wireguard → backup)

## 5 — Connect via WireGuard

Add a `[Peer]` block to `/etc/wireguard/wg0.conf` on the server for your
admin client, then connect. Moodle is only reachable through the tunnel.

## 6 — Verify

```bash
MOODLE_HOST=lms.example.com bash tests/integration/integration_test.sh
MOODLE_HOST=lms.example.com bash tests/security/security_test.sh
```
