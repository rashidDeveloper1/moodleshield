# SCORM 1.2 Sample Package

A minimal SCORM 1.2 Shareable Content Object (SCO) used to verify that Moodle correctly launches SCORM content and records completion status.

## Files

| File | Purpose |
|------|---------|
| `imsmanifest.xml` | SCORM package manifest — defines the course structure and mastery score |
| `index.html` | The SCO itself — initialises the SCORM API on load and marks the lesson passed on button click |

## Package and Upload

```bash
cd examples/scorm-sample
zip -r ../moodleshield-sample-scorm.zip .
```

Upload `moodleshield-sample-scorm.zip` to Moodle:

1. Inside a course, turn editing on
2. Add activity → SCORM package
3. Upload the zip file
4. Save and display

## What It Tests

- Moodle SCORM player launches the SCO in an iframe
- `LMSInitialize` and `LMSSetValue` calls reach the API injected by the player
- Clicking "Mark Complete" sets `cmi.core.lesson_status` to `passed` and `cmi.core.score.raw` to `100`
- `LMSFinish` commits the session — Moodle records the completion in the gradebook
- The mastery score in the manifest (`adlcp:masteryscore = 80`) means a score of 100 results in a `passed` status
