# Feishu Relay Avatar Upload Design

## Goal

Allow each Feishu-to-WuKongIM forwarding route to use an uploaded local image as the relay avatar shown in the target WuKongIM group.

## Requirements

- The existing manual avatar URL field remains available.
- The route configuration sheet adds an upload action next to the avatar field.
- On Windows desktop, the action opens a local image picker.
- The selected image is uploaded to WuKongIM media storage and the returned public media URL is written into the avatar field.
- The saved route continues using the existing `relayAvatar` field.
- Upload failures are shown in the sheet and do not close the route picker.

## Architecture

`FeishuMonitorCenterPage` receives two injectable callbacks: one for picking an image path and one for uploading that path. The default picker uses the existing `pickSingleLocalImagePath`; the default uploader uses `FileApi.uploadCommonImage` with a stable `feishu-relay-avatar/` object prefix. `_TargetGroupPicker` owns upload UI state and writes successful upload URLs into its existing avatar text controller.

This keeps forwarding payloads unchanged: message content still carries `robot.avatar`, and all clients can render the avatar because the value is a server URL rather than a local path.

## Error Handling

- If the user cancels image selection, the sheet remains unchanged.
- If upload returns an empty URL, the sheet shows a short failure message.
- If picker or upload throws, the sheet shows the exception text for diagnosis.

## Testing

- Widget test injects fake picker/uploader callbacks.
- Test verifies upload button calls both callbacks, fills the avatar field with the returned URL, and saves the route with that URL after selecting a target group.
