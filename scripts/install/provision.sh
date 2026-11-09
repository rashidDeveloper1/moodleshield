#!/usr/bin/env bash
# Full-stack provisioning: Terraform → Ansible.
# Usage: ./scripts/install/provision.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"
ANSIBLE_DIR="$REPO_ROOT/ansible"

echo "==> Initialising Terraform..."
terraform -chdir="$TF_DIR" init -input=false

echo "==> Applying Terraform plan..."
terraform -chdir="$TF_DIR" apply -auto-approve -input=false

PRIMARY_IP=$(terraform -chdir="$TF_DIR" output -raw primary_public_ip)
REPLICA_IP=$(terraform -chdir="$TF_DIR" output -raw replica_public_ip)

sed -i "s/<PRIMARY_PUBLIC_IP>/$PRIMARY_IP/" "$ANSIBLE_DIR/inventory.ini"
sed -i "s/<REPLICA_PUBLIC_IP>/$REPLICA_IP/" "$ANSIBLE_DIR/inventory.ini"

echo "==> Primary: $PRIMARY_IP  |  Replica: $REPLICA_IP"

echo "==> Waiting for SSH on primary..."
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    -i ~/.ssh/moodleshield "root@$PRIMARY_IP" exit 2>/dev/null; do
    sleep 5
done

echo "==> Running Ansible playbook..."
ansible-playbook \
    -i "$ANSIBLE_DIR/inventory.ini" \
    "$ANSIBLE_DIR/site.yml" \
    --ask-vault-pass

echo "==> Provisioning complete. Moodle is available at https://$PRIMARY_IP"
