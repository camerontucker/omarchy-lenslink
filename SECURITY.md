# Security boundary

Report vulnerabilities privately through GitHub's security reporting when
available, or contact the maintainer without posting credentials or camera
frames in a public issue.

This is unsandboxed user code for a trusted Omarchy desktop. System Python,
Quickshell/Qt, OBS, LensLink and the user-owned plugin directory are trusted.
The plugin creates no network listener, invokes no shell for runtime controls,
and installs no packages, downloaded code or services. An optional button
starts the existing fixed user service `obs-lenslink.service`.

Camera commands use loopback HTTP on port 9980. OBS commands use a loopback
WebSocket and privately read the user's OBS configuration. File reads reject
unsafe ancestry, symlinks, FIFOs, hard links, non-private credential modes and
oversized input. Passwords are used for challenge-response, not printed.
These client controls do not authenticate the identity of a loopback server.

Wi-Fi switching intentionally asks OBS/LensLink to dial the user-entered phone
IP. This is an explicit local-user action; it does not expose remote control of
the shell. Numeric address validation is not an enforced same-subnet policy.
Use trusted networks. Phone transport security, pairing and native media
parsers belong to upstream LensLink/OBS/Qt and are outside this code review.

The fixed input name/kind and single-source registry are checked before
connection changes; only mode/host are overlaid and settings are read back.
Readback confirms saved settings, not phone identity or successful connection.
Concurrent source replacement is not atomic across upstream API calls.

Network JSON, WebSocket messages, stdout/stderr and individual requests are
bounded. The persistent preview helper has per-request deadlines and exits on
stdin EOF; it is stopped when the panel closes. It launches no subprocesses.
Preview frames stay in memory and show the whole current OBS program scene.
Closing the panel does not stop a shared virtual-camera output.

The Wi-Fi diff review and its limits are recorded in docs/SECURITY_VERIFICATION.md.
Marketplace validation is not a security certification.
