# 2026-04-05 Contacts Strings Resource Layer Design

## Scope

This spec defines a lightweight contacts-domain strings resource layer for the Flutter app.

It covers:

- default contacts header menu strings
- contacts page strings
- new friends page strings
- create group page strings
- contacts viewport empty-state and count strings

It does not cover:

- global app-wide localization infrastructure
- search-domain strings
- full locale switching in `MaterialApp`
- non-contacts modules

## Problem

The current Flutter contacts surface mixes hardcoded strings across page widgets and slot assembly code.

Confirmed mismatch:

- default contacts header slot text is still hardcoded as English `New friends` and `Saved groups`
- Android original strings are `新朋友` and `保存的群聊`
- page-level contacts strings are also scattered across multiple files
- there is no existing shared contacts-domain strings entrypoint

This creates two concrete problems:

1. Android parity breaks because default contacts entry text can drift from the original app.
2. Future migration toward proper localization will be harder because contacts strings are duplicated and fragmented.

## Chosen Approach

Introduce a lightweight contacts-domain strings resource object with a pure-Dart resolver.

Why this approach:

- it fixes the current Android parity issue immediately
- it removes direct hardcoded defaults from both pages and slot assembly
- it works in files that do not have `BuildContext`, such as slot assembly
- it creates a clean migration path toward fuller localization later without forcing a large framework change now

## Design

### 1. Resource Layer

Add a new file:

- `lib/modules/contacts/contacts_strings.dart`

This file will define:

- an immutable `ContactsStrings` model
- a small `resolveContactsStrings()` entrypoint
- a default Simplified Chinese value set
- an extension point for future locale-specific variants

The first version will behave as a domain resource layer, not as a full Flutter localization system.

### 2. Initial String Surface

The first version of `ContactsStrings` will cover the contacts-domain text that is currently part of the approved scope:

- header menu labels:
  - `newFriends`
  - `savedGroups`
- contacts page labels:
  - `contactsTitle`
  - `contactsLoading`
  - `contactsLoadFailed`
  - `setRemark`
  - `sendMessage`
  - `remarkDialogTitle`
  - `remarkDialogHint`
  - `cancel`
  - `save`
- new friends page labels:
  - `newFriendsTitle`
  - `newFriendsLoading`
  - `newFriendsLoadFailed`
  - `newFriendsEmpty`
  - `newFriendsEmptyHint`
  - `requestAddFriend`
  - `approve`
  - `processing`
  - `processed`
  - `delete`
- create group page labels:
  - `selectContactsTitle`
  - `searchPlaceholder`
  - `confirmWithCount`
  - `createGroupFailedPrefix`
- contacts viewport labels:
  - `contactsEmpty`
  - `contactsEmptyHint`
  - `contactsCount`

Default Simplified Chinese values must align with the Android original where reference strings exist.

Confirmed Android-aligned defaults include:

- `新朋友`
- `保存的群聊`

### 3. Resolver Shape

Use the smallest practical API:

- pages and widgets call `final strings = resolveContactsStrings();`
- slot assembly also calls the same resolver

The first version does not introduce a Riverpod provider for strings.

Why:

- there is no active global locale switching pipeline yet
- a provider would add indirection without immediate benefit
- this keeps the resource layer usable from both widget and non-widget code

If global locale switching is introduced later, the resolver can be upgraded behind the same call sites.

### 4. Integration Points

Replace direct hardcoded contacts strings at these integration points:

- `lib/modules/contacts/contacts_slot_assembly.dart`
- `lib/modules/contacts/contacts_page.dart`
- `lib/modules/contacts/new_friends_page.dart`
- `lib/modules/contacts/create_group_page.dart`
- `lib/modules/contacts/widgets/contacts_list_viewport.dart`

Integration rules:

- default contacts header menus must read from the resource layer
- page-level static contacts strings in scope must read from the resource layer
- custom `headerMenus` passed in from outside remain untouched
- no behavior or navigation logic changes are bundled into this strings refactor

### 5. Android Parity Rules

This resource-layer migration must preserve strict Android parity for the contacts-domain defaults in scope.

Specifically:

- default header entry text must match Android wording
- page titles and action labels already aligned to Android should stay aligned
- this change must not weaken existing contacts parity tests

### 6. Testing

Use TDD for the strings refactor.

Add or update tests for:

- `contacts_page_parity_test.dart`
  - verify default header entries render `新朋友` and `保存的群聊`
- a new `contacts_strings_test.dart`
  - verify default resolved strings return the expected Simplified Chinese values
- a new `contacts_slot_assembly_test.dart`
  - verify `resolveContactsHeaderMenus()` uses the resource layer for default labels

The goal is not to exhaustively test every single migrated string in one pass.

The goal is to lock:

- Android-parity defaults
- resource-layer ownership of those defaults
- stable contacts entry rendering

## Risks

- This is not a full localization framework. It reduces future migration cost but does not itself add runtime locale switching.
- Some contacts-domain files still contain historic mojibake text. This spec only migrates the approved contacts surface in scope.
- If additional contacts strings are added later without using the resource layer, fragmentation can return.

## Non-Goals

- converting the entire project to `arb` or generated Flutter localizations in this step
- cleaning every corrupted historic string in the repository
- migrating search, chat, auth, or user modules in this step
- changing server contracts or data flow

## Verification

Success means:

- default contacts header entries render `新朋友` and `保存的群聊`
- contacts files in scope no longer hardcode those default labels directly
- new contacts-domain strings tests pass
- updated contacts parity tests pass
- no new analyzer issues are introduced in touched files
