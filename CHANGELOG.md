# Changelog

## 0.5.0 — 2026-09-17

- Add landscape, portrait and flipped orientation controls while retaining the
  current crop and fitting portrait video within the OBS canvas.
- Keep the selected orientation index stable during activation and provide a
  dedicated 180° rotation button.
- Confirm control compatibility with LensLink 1.10.0 through 1.12.0 and current
  OBS Studio 32.2.
- Explain that LensLink supports Portrait background blur only on the Front
  camera and show the required phone-side restart steps in the panel.

## 0.4.0 — 2026-09-04

- Add Wi-Fi/IP and USB switching with exact-source checks and settings readback.
- Keep the source crop and unrelated connection/audio settings when switching.
- Display configured transport separately from actual connection status.
- Add security and release regressions, CI and a synthetic marketplace preview.
- Normalize IPv4-mapped addresses before validation and remove unused OBS CLI.

## 0.3.1 — Initial implementation

- In-panel LensLink camera, exposure, white-balance, format and audio controls.
- OBS virtual-camera and in-memory screenshot previews.
- Draggable crop, trackpad/scroll zoom and continuous preview during dragging.
