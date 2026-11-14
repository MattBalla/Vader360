# Changelog

## v1.0.0

- First release: DashLaunch plugin with the two kernel 17559 patches for the Flydigi Vader 3
  receiver (64-byte interrupt endpoint, 32-byte input reports).
- Signature checks around both patch sites; nothing is changed on an unknown kernel.
- `vader360-check.ps1`: checks (or applies, with `-Apply`) the patches over XBDM.
