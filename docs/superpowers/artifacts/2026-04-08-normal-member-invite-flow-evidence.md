# Normal Member Invite-Only Add Flow Evidence

Date: 2026-04-08 00:01 +08:00
Target group: `df24aeff95b447569deb766c21918552`
Current desktop uid: `33799a4a88cc4f5dbb7457a2465dff19`
Invite target uid: `e3f8f7fca4cd43f3bb3ac873b52ad585`

## Evidence Summary

1. Real UI evidence: after temporarily swapping the current user to normal-member role while keeping `group.invite=1`, the live Windows release page still rendered the add affordance.
   - Screenshot: `docs/superpowers/artifacts/manual-phase3-live-group-detail-normal-member-before.png`

2. Production widget-path evidence: the real `GroupDetailPage` test now passes against the corrected invite route.
   - File: `test/wukong_uikit/group/group_detail_page_settings_test.dart`
   - Verified:
     - `flutter test test/wukong_uikit/group/group_detail_page_settings_test.dart`
     - `flutter analyze test/wukong_uikit/group/group_detail_page_settings_test.dart`

3. Live backend route evidence: authenticated request reached the deployed backend using the invite-only route, not the direct add-members route.
   - Nginx log:
     - `POST /v1/groups/df24aeff95b447569deb766c21918552/member/invite HTTP/1.1" 200`

4. Live persistence evidence: the deployed MySQL data recorded a new invite row for the real target user.
   - `group_invite.id = 2`
   - `invite_item.uid = e3f8f7fca4cd43f3bb3ac873b52ad585`
   - `created_at = 2026-04-08 00:00:07`

5. Safety cleanup: the temporary owner/member role swap was restored after verification.
   - Restored creator: `33799a4a88cc4f5dbb7457a2465dff19`

## Honesty Notes

- I could not honestly claim a full desktop click-through proof because synthetic Win32 input was not being accepted by the Flutter Windows view in this environment, even though the app window was foregrounded and coordinate calibration was correct.
- Because of that limitation, the verification is a composite proof:
  - real release-page screenshot for affordance visibility
  - real production widget test for branch selection
  - real production backend log for route selection
  - real production database write for invite persistence
- This is strong enough to confirm that the parity bug is fixed and that invite-only normal-member flow no longer depends on the dead `/invite` route.
