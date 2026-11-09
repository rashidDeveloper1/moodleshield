# Test Evidence

This directory is populated after a real deployment run.

Expected contents after running the test suites:

| File | Source |
|------|--------|
| `integration-test.log` | `tests/integration/integration_test.sh` output |
| `security-test.log` | `tests/security/security_test.sh` output |
| `performance-test.log` | `tests/performance/pdf_perf_test.sh` output |
| `restic-snapshots.txt` | `restic snapshots --tag moodleshield` output |
| `screenshots/` | Browser screenshots of Moodle, SCORM player, Reading Library |

CI artifacts are uploaded automatically by the GitHub Actions workflow on every `main` branch run.
