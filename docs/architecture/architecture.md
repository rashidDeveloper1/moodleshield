# Architecture

## Component Overview

```
Internet
    │
    ▼
Hetzner Floating IP (static)
    │
    ▼
UFW Firewall
  ├── :22   SSH (admin IPs only)
  ├── :51820 WireGuard UDP (all)
  └── :443  HTTPS (WireGuard subnet only)
    │
    ▼
WireGuard VPN (wg0 — 10.10.1.0/24)
    │
    ▼
Nginx (TLS termination, security headers, PHP-FPM proxy)
    │
    ├── PHP-FPM 8.4 (Moodle 5.3 application)
    │       │
    │       ├── PostgreSQL 17 (persistent data)
    │       └── Redis (sessions + MUC cache)
    │
    └── Static assets (served directly by Nginx)
```

## Network Isolation

- HTTPS is only reachable through the WireGuard tunnel.
- PostgreSQL and Redis bind to `127.0.0.1` only — no external exposure.
- PDF files live in `moodledata` (outside the web root) and are streamed
  through `view_pdf.php` with a single-use token. Nginx returns 403 for
  any direct `.pdf` request.

## Disaster Recovery

A second Hetzner server (replica) runs the same base stack.
Restic snapshots (PostgreSQL dump + web root + moodledata) are pushed to
Backblaze B2 daily at 02:00 UTC. The `scripts/restore/restore.sh` script
pulls the latest snapshot and rebuilds the site in under 30 minutes.

## Air-Gapped Deployment

`scripts/offline/build_mirror.sh` downloads all required `.deb` packages
and builds a local APT repository with a `Packages.gz` index and
`SHA256SUMS` file. The target server points `apt` at the local mirror and
never contacts the internet.

## Reading Library Plugin

```
Teacher uploads PDF → stored in moodledata (not web root)
Student clicks Borrow → borrow_manager issues a 64-byte random token
Student opens PDF → view_pdf.php validates token, streams file, rotates token
Student returns book → token invalidated, copy freed for next borrower
```

Tokens are single-use and rotate on every read, preventing link sharing.
