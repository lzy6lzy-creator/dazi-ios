# Hybrid SMS And Invitation Login Design

## Goal

Support real dynamic SMS verification for every user while retaining `121212` as an additional login code for configured whitelist phones. Keep invitation requirements limited to new non-whitelist registrations and render the actual free-registration target returned by the backend.

## Authentication Rules

- Existing users may request and use a dynamic SMS code without an invitation.
- Whitelist users may either enter the configured internal code `121212` directly or request and use a dynamic SMS code.
- Non-whitelist users may only use a valid dynamic SMS code.
- New whitelist users bypass invitation requirements because whitelist membership is an explicit internal admission grant.
- New non-whitelist users require a signup admission token. During `open` registration the token is issued without an invite; during `invite_only` registration a valid invite is required before SMS is sent.
- A fixed-code login never calls the SMS verification provider. Every other submitted code is checked by the provider.

## Send-Code Flow

`POST /api/v1/auth/send-code` performs all classification server-side:

1. Normalize the phone and determine whether the user already exists and whether the phone is whitelisted.
2. Existing users and whitelist users receive a signup admission immediately and continue to rate limiting and real SMS delivery.
3. New non-whitelist users in `open` mode receive an open admission and real SMS delivery.
4. New non-whitelist users in `invite_only` mode receive a structured `403 invitation_required` response when no invite is supplied. No SMS is sent.
5. Supplying a valid invite reserves it, issues an admission, and sends the SMS. Invalid invites return the existing unavailable error and do not send SMS.

Successful responses include:

- `admission_token`, `expires_in`, and `registration_mode`.
- `user_state`: `existing`, `whitelist`, or `new`.
- `invitation_state`: `hidden`, `not_required`, or `required`.
- `qualified_user_count` and `qualified_target`, sourced from the current invitation program.

The structured `invitation_required` error includes the same count and target so iOS never hardcodes `N`.

## iOS Interaction

- The login button becomes available for any valid 11-digit phone and 6-digit code; the backend remains authoritative.
- The code field is never auto-filled.
- Existing and whitelist users do not see an invitation field after a successful send.
- A new user in the free-registration phase sees the same invitation field in a disabled gray state containing `前 N 位用户免邀请码`, where `N` is `qualified_target` from the response.
- A new user in invite-only mode sees that field enabled. The first send attempt only reveals the field; after the user enters a valid invite and taps send again, the backend sends the SMS.
- The disabled and enabled variants share one SwiftUI component and stable dimensions.

## Configuration And Security

- `INTERNAL_TEST_CODE`, `INTERNAL_TEST_PHONES`, and `INTERNAL_TEST_PHONES_FILE` are backend-only settings.
- The default internal code is `121212`; production may override it through `.env`.
- Whitelist parsing accepts comma-separated settings and a mounted file, normalizes phone values, and ignores comments or malformed entries.
- iOS does not contain the fixed code or whitelist.
- Existing SMS rate limits continue to apply when a real SMS is requested, including for whitelist users.

## Error Handling

- `403 whitelist` is removed because non-whitelist users are allowed to use dynamic SMS.
- `403 invitation_required` reveals the enabled invitation field and does not show a network error.
- Invalid invites, throttling, provider configuration failures, and provider send failures keep distinct user-facing messages.
- Provider verification failure returns `验证码错误`; fixed-code failure falls through to provider verification so dynamic codes remain valid for whitelist users.

## Verification

- Backend route tests cover every user-state branch, no-send behavior for missing invites, real-send behavior for allowed branches, fixed-code bypass, dynamic verification, and non-whitelist rejection of `121212`.
- Invitation service tests cover whitelist admission metadata and real policy counts.
- iOS contract tests cover response decoding, structured error parsing, and the shared disabled/enabled invitation field.
- Run the backend suite, iOS static suite, `git diff --check`, and an iOS Simulator build before completion.
