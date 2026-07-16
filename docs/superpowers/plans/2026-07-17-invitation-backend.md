# App Invitation Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the App registration invitation backend: open Shanghai cold start, invitation-only transition after 500 qualified users, admission reservations, Shanghai location eligibility, and one-time `+3/+2` rewards.

**Architecture:** Store all counters as auditable SQLAlchemy models and use row locks for reservations, redemptions, rewards, and the 500-user transition. Keep auth routes thin by delegating admission and reward state machines to focused services. Preserve existing-user login in every registration mode and preserve TestFlight as an independent installation channel.

**Tech Stack:** FastAPI, SQLAlchemy async/PostgreSQL, Redis async rate limiting, Pydantic 2, Python `unittest` plus PostgreSQL integration tests.

## Global Constraints

- Cold-start city code is `310000`; target is exactly `500` different qualified users.
- `open` admissions remain valid for 10 minutes after an automatic transition to `invite_only`.
- First valid event publish grants `+3` once; first successful matched chat room grants `+2` once per user.
- Rewards require a fresh Shanghai location verification; otherwise the milestone remains `pending_location`.
- Existing users never need an invitation code and never consume invitation balance.
- Invitation codes are stable, eight characters, uppercase, and exclude ambiguous characters.
- Available balance is `granted_total - consumed_total - reserved_total` and must never be negative.
- Exact coordinates are evaluated in memory and never stored.
- TestFlight invitation operations must remain independent from App registration.

---

### Task 1: Invitation persistence and pure policy

**Files:**
- Create: `dazi-server/app/models/invitation.py`
- Create: `dazi-server/app/services/invitation_policy.py`
- Create: `dazi-server/tests/test_invitation_policy.py`
- Create: `dazi-server/tests/test_invitation_models_static.py`
- Modify: `dazi-server/app/main.py`

**Interfaces:**
- Produces models `InvitationProgram`, `UserInvitationAccount`, `InvitationLedger`, `SignupAdmission`, `LocationVerification`, and `InvitationMilestone`.
- Produces pure functions `available_balance(account)`, `is_admission_active(admission, now)`, `is_location_current(verification, now)`, `point_in_shanghai(lat, lon)`, and `should_transition(count, target)`.

- [ ] Write tests for balance, 10-minute expiry, 30-day location expiry, Shanghai/Hangzhou/Suzhou coordinates, and the exact 500 transition.
- [ ] Run `python3 -m unittest tests/test_invitation_policy.py tests/test_invitation_models_static.py` and confirm imports fail.
- [ ] Implement the six models with unique constraints for `code`, `idempotency_key`, `(user_id, milestone_type)`, and redemption `invitee_user_id`.
- [ ] Implement the pure policy functions and import all models in `app/main.py` so `Base.metadata.create_all` creates tables.
- [ ] Run the focused tests and confirm GREEN.

### Task 2: Registration policy and signup admissions

**Files:**
- Create: `dazi-server/app/services/invitation_service.py`
- Create: `dazi-server/tests/test_invitation_registration.py`
- Modify: `dazi-server/app/api/schemas.py`
- Modify: `dazi-server/app/api/auth.py`
- Modify: `dazi-server/app/main.py`

**Interfaces:**
- Produces `get_registration_policy(db) -> RegistrationPolicy`.
- Produces `issue_signup_admission(db, phone, invite_code) -> IssuedAdmission`.
- Produces `cancel_signup_admission(db, raw_token)`, `record_failed_verification(db, raw_token)`, and `consume_signup_admission(db, raw_token, invitee_user_id)`.
- Extends `AuthSendCodeRequest` with optional `invite_code` and `install_id`; extends `AuthLoginRequest` with optional `admission_token`.

- [ ] Write PostgreSQL integration tests proving open admission, paused rejection, invitation reservation, last-slot locking, expiration release, existing-user bypass, and pre-transition open-token grace.
- [ ] Run the focused test and confirm RED.
- [ ] Implement raw token generation with `secrets.token_urlsafe(32)` and store only SHA-256 hashes.
- [ ] Lock the program row for new-user policy decisions and lock invitation accounts for reserve/release/consume transitions.
- [ ] Add `GET /api/v1/auth/registration-policy`.
- [ ] Change `/send-code` to issue an admission before sending and cancel it if sending fails; return `admission_token`, `expires_in`, and `registration_mode`.
- [ ] Change `/login` to verify SMS first, bypass admission for an existing user, and require/consume a valid admission for a new user.
- [ ] Add Redis rate limits: same phone once per 60 seconds, phone 10/day, IP 30/hour. Return HTTP 429 without revealing account existence.
- [ ] Run focused tests and existing auth tests.

### Task 3: Public invitation API

**Files:**
- Create: `dazi-server/app/api/invitations.py`
- Create: `dazi-server/tests/test_invitations_api.py`
- Modify: `dazi-server/app/api/schemas.py`
- Modify: `dazi-server/app/main.py`

**Interfaces:**
- Produces `GET /api/v1/invitations/me` with code, granted, consumed, reserved, available, and milestone states.
- Produces `GET /api/v1/invitations/{code}/status` with only `valid` and `available`; it exposes no inviter identity.

- [ ] Write failing API/service tests for no-account state, active balance, suspended code, exhausted code, and privacy-safe public output.
- [ ] Implement query functions and routes.
- [ ] Register the router in `app/main.py` and run focused tests.

### Task 4: Shanghai location verification and reward settlement

**Files:**
- Create: `dazi-server/app/api/location_eligibility.py`
- Create: `dazi-server/app/services/invitation_reward_service.py`
- Create: `dazi-server/tests/test_invitation_rewards.py`
- Modify: `dazi-server/app/api/schemas.py`
- Modify: `dazi-server/app/main.py`

**Interfaces:**
- Produces `record_milestone(db, user_id, milestone_type, source_id)`.
- Produces `verify_launch_city_location(db, user_id, lat, lon, accuracy, captured_at)`.
- Produces `settle_pending_milestones(db, user_id)`.

- [ ] Write failing tests for stale coordinates, accuracy worse than 1 km, Shanghai qualification, non-Shanghai rejection, pending rewards, idempotent `+3/+2`, and user count transition `499 -> 500`.
- [ ] Implement coordinate validation and store only city result, accuracy, risk flags, and timestamps.
- [ ] On first settled reward, create a stable account/code, set `first_qualified_at`, increment the locked program count once, and hard-switch to `invite_only` at 500.
- [ ] Add authenticated `POST /api/v1/location/verify` and register the router.
- [ ] Run focused tests.

### Task 5: Publish and successful-match hooks

**Files:**
- Modify: `dazi-server/app/api/events.py`
- Modify: `dazi-server/app/services/matching_service.py`
- Create: `dazi-server/tests/test_invitation_reward_hooks_static.py`

**Interfaces:**
- Event creation records `first_event_publish` with source event ID after the event flushes.
- A room promoted/created as `matched` records `first_match` for both event owners with source room ID.

- [ ] Write static and helper tests that fail while hooks are absent.
- [ ] Add each hook inside a nested transaction/savepoint so reward failure cannot roll back event creation or a successful match.
- [ ] Ensure negotiating A2A rooms do not trigger rewards; only `phase == "matched"` rooms do.
- [ ] Run hook tests and the full backend suite.

### Task 6: Operational verification

**Files:**
- Modify: `dazi-server/tests/test_invitation_registration.py`
- Modify: `dazi-server/tests/test_invitation_rewards.py`

- [ ] Run PostgreSQL concurrency tests for two reservations competing for one remaining slot.
- [ ] Run `python3 -m unittest discover -s tests`.
- [ ] Run `python3 -m compileall` with a writable cache prefix.
- [ ] Run `docker compose ... config --quiet` with validation-only required values.
- [ ] Run `git diff --check` and verify local `.env` remains ignored.
