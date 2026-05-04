# Desktop Device-Lock Test Mode Design

## Goal

Enable item `1.5` login secondary verification to be tested from the existing Windows desktop client without changing the production backend device-lock policy.

## Constraint

- Only the Windows desktop Flutter client is available.
- Production backend currently enforces login secondary verification only when login `flag == APP (0)`.
- Desktop runtime normally reports `PC (2)`.
- Local desktop device identity is persisted across logins, so the backend may continue treating the machine as an already trusted device.

## Chosen Approach

Use a local debug-only runtime override for the desktop client's device flag during this test session, then clear the local persisted device identity before relaunch.

### Runtime override

- Add a debug-only device-flag override hook to `IMConfig`.
- Read the override from a Dart define during startup.
- Use it for login/device bind/IM connect/logout because all of those already consume `IMConfig.currentDeviceFlag`.

### Local identity reset

- Do not change production backend logic.
- Before relaunching the desktop app in this temporary mode, clear the local persisted device identity keys from the desktop shared-preferences store so the backend sees a new device.

## Why this approach

- Preserves the real end-user click flow.
- Avoids broadening production device-lock enforcement to `PC`.
- Keeps the change local to the debugging session and easy to revert by relaunching without the override.

## Verification

- Unit test the debug override behavior.
- Relaunch Windows app with the override.
- Confirm the next login returns the secondary verification path instead of going directly to the message list.
- Continue the interactive test using the existing fixed verification code path `123456`.
