# Marketplace submission

Title: `[Plugin]: iPhone LensLink`

The owner authorized commit, push and marketplace submission on 2026-09-04.

### Repository URL

https://github.com/camerontucker/omarchy-lenslink

### Category

Hardware

### Tags

bar, quickshell, media

### Suggest a missing tag

webcam

### Maintainer notes

iPhone LensLink adds camera controls and live OBS framing to the Omarchy bar. It supports an existing LensLink iPhone camera over USB or Wi-Fi, with explicit connection switching, camera/exposure/white-balance/format/audio controls, preview, trackpad zoom and smooth draggable crop. LensLink limits Portrait background blur to the Front camera and keeps its system-effects settings on the phone; the panel states that constraint explicitly.

Requires Omarchy Quattro, system Python/Qt Multimedia, OBS Studio 32+ with WebSocket enabled, and LensLink on the computer and phone. Compatible with LensLink 1.10.0–1.12.0; live-tested with 1.10.0 and checked against the tagged 1.12.0 control API. The README documents the exact scene/source names and installation, update and removal. The plugin has no third-party Python dependencies, telemetry, package installation, downloaded executables, or privileged operations. An optional Start OBS button starts only an existing fixed user service; it does not create one.

The helper APIs remain loopback-only. Wi-Fi switching asks OBS/LensLink to use an explicitly entered numeric phone address. Changes check the existing source name/kind, overlay only mode/host, and verify settings readback. Shared OBS virtual-camera output is changed only by explicit buttons. Preview shows the current OBS program scene and stays in memory. Use a trusted network; the external phone protocol is not audited here.

The Wi-Fi commit received a completed static security diff review with no confirmed vulnerabilities. Follow-up tests cover address normalization, source isolation, unsafe credential files, malformed JSON, OBS time/frame bounds and marketplace payload exclusions. The earlier Anker C200 review informed these checks; this plugin has no controller compiler/cache or process-discovery feature. See docs/SECURITY_VERIFICATION.md for scope and limits. Local checks include 45 Python tests, six functional QML checks (12 runner passes), manifest validation and QML lint.

The root preview uses the same synthetic wooden mannequin image as the owner's Anker C200 listing. It captures the real QML panel with illustrative values, is marked example, and contains no actual phone address, camera frame or desktop. Asset provenance and MIT redistribution are documented in docs/ASSETS.md. Capture-only hooks and private development/agent files are excluded from the published payload.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
