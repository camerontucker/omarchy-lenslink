# Verification — 2026-09-17

- 45 Python unit, security and release tests pass, covering source isolation, range/capability gates,
  read-only polling, preview bounds, framing and Wi-Fi/USB settings updates.
- Six functional QML tests pass (12 including setup/teardown), including
  continuous preview completion before drag release, coalesced requests,
  scroll zoom, drag behavior in a scroll container and stable held sliders.
- QML lint exits successfully with host/dynamic Process type warnings.
  Source and installed manifests validate with Omarchy Quattro.
- Live Wi-Fi connection confirmed: iPhone front camera, 1080p30 HEVC,
  automatic exposure and white balance. The installed panel received preview
  frames without errors. Virtual-camera output remained stopped.
- Earlier USB tests confirmed preview, camera control readback and clamped
  framing. Original framing was restored after those gesture tests.
- Physical trackpad pinch, external meeting-app reception and every phone
  control were not tested live. Unit tests cover control payload validation.

Wi-Fi source settings use overlay updates for only mode and host and are read
back from OBS. Tests reject malformed addresses, wrong source kinds and failed
readback. USB switching retains the saved host. No device address, credentials,
private camera images or development instruction files are distributed.

The final release also runs checks from a fresh clone: tests/run verifies
Python tests, installer syntax, the manifest and six functional QML checks
(12 runner passes including setup and teardown).
Security regressions cover unsafe credential files, malformed JSON, socket
EOF and drip/ping bounds, mapped-address normalization and release exclusions.
