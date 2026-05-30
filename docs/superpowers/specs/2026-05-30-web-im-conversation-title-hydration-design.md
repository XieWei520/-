# Web IM Conversation Title Hydration Design

## Goal

Replace fallback conversation titles such as `用户 d16e` and `群聊 8487` with real user or group names in the Web IM conversation list, while keeping the existing fallback behavior when profile lookup fails.

## Scope

- Web IM only: all implementation lives under `web_im`.
- Use existing signed HTTP authentication and runtime configuration.
- Do not change Flutter Windows, Android, or shared Dart code.
- Do not change the `/v1/conversation/sync` backend contract.

## API Sources

- User conversations (`channel_type: 1`) hydrate from `GET /v1/users/{uid}`.
- Group conversations (`channel_type: 2`) hydrate from `GET /v1/groups/{groupNo}`.
- The client accepts common name fields from these responses: `remark`, `name`, `username`, `group_name`, `groupName`, `channel_name`, `channelName`, `display_name`, and `displayName`.

## Behavior

1. `loadConversations` first renders the synced conversation list using the current safe fallback mapping.
2. It then attempts to hydrate only conversations that still use fallback titles.
3. Successful profile lookups replace `title` and `avatarText`; `channelId`, `channelType`, unread counts, timestamps, and routing identifiers remain unchanged.
4. Lookup failures are non-fatal. Failed conversations keep their fallback titles and the list remains usable.
5. Hydrated names are cached by `channelType:channelId` for the current Web session to avoid repeated profile calls during navigation.

## Testing

- Unit tests cover user and group profile response parsing.
- Store tests cover hydrated titles, fallback preservation on lookup failure, cache reuse, and unchanged routing identifiers.
- Live E2E covers backend sync plus profile hydration on iPhone and desktop projects.
- Build and browser probes verify that hydrated names still fit the mobile conversation list.
