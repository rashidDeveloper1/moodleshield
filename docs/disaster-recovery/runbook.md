# Disaster Recovery Runbook

## Objective

Restore MoodleShield to the replica server from the latest Restic snapshot
within 30 minutes of a primary server failure.

## Step 1 — Reassign the Floating IP

```bash
# Point the Hetzner Floating IP at the replica
terraform -chdir=terraform apply \
  -var="floating_ip_target=replica" \
  -auto-approve
```

## Step 2 — SSH into the replica

```bash
ssh -i ~/.ssh/moodleshield root@<REPLICA_IP>
```

## Step 3 — Run the restore script

```bash
bash /opt/moodleshield/scripts/restore/restore.sh
```

To restore a specific snapshot instead of the latest:

```bash
# List available snapshots
source /etc/restic-env && restic snapshots --tag moodleshield

# Restore a specific snapshot
bash /opt/moodleshield/scripts/restore/restore.sh <snapshot-id>
```

## Step 4 — Verify the restore

```bash
MOODLE_HOST=lms.example.com \
MOODLE_PASS=<admin-pass> \
bash /opt/moodleshield/tests/integration/integration_test.sh
```

All tests must pass before declaring recovery complete.

## Step 5 — Update DNS (if not using Floating IP)

Point your DNS A record at the replica's public IP and wait for TTL
propagation (set TTL to 60 seconds before any planned maintenance).

## Recovery Time Objective

| Phase                  | Target   |
|------------------------|----------|
| Floating IP reassign   | < 1 min  |
| Restic restore         | < 20 min |
| Service verification   | < 5 min  |
| Total RTO              | < 30 min |
