# Hybrid SMS And Invitation Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow whitelist users to log in with either `121212` or a real SMS code, require dynamic SMS for all other users, and show one invitation field whose state and actual free-user target come from the backend.

**Architecture:** Extend the existing invitation admission service so `/send-code` returns user and invitation display metadata while continuing to own invite reservation. Add a backend-only whitelist helper used by both send and login routes. iOS decodes the structured result and maps it into a single invitation-field state.

**Tech Stack:** FastAPI, SQLAlchemy async, Pydantic v2, unittest, SwiftUI, Swift Codable, xcodebuild.

## Global Constraints

- Product name remains `i搭不搭`.
- Android is out of scope.
- iOS never stores or auto-fills `121212` and never stores the whitelist.
- `qualified_target` from the backend is the only source for `N` in `前 N 位用户免邀请码`.
- Existing dirty worktree changes must be preserved.

---

### Task 1: Backend Whitelist And Admission Metadata

**Files:**
- Create: `dazi-server/app/services/internal_test_access.py`
- Modify: `dazi-server/app/core/config.py`
- Modify: `dazi-server/app/services/invitation_service.py`
- Modify: `dazi-server/.env.example`
- Modify: `dazi-server/docker-compose.prod.yml`
- Test: `dazi-server/tests/test_internal_test_access.py`
- Test: `dazi-server/tests/test_invitation_registration.py`
- Test: `dazi-server/tests/test_beta_signup_static.py`

**Interfaces:**
- Produces: `is_internal_test_phone(phone: str, allowed_phones_csv: str | None, allowed_phones_file: str | None) -> bool`.
- Produces: `is_internal_test_code(phone: str, submitted_code: str, configured_code: str | None, allowed_phones_csv: str | None, allowed_phones_file: str | None) -> bool`.
- Extends: `issue_signup_admission(..., whitelist_bypass: bool = False) -> IssuedAdmission` with `admission_type`, `qualified_user_count`, and `qualified_target` metadata.

- [ ] **Step 1: Write failing whitelist parser tests**

Cover CSV and file union, phone normalization, comments, malformed rows, correct fixed code, and rejection for a non-whitelist phone using literal fixtures.

- [ ] **Step 2: Run whitelist tests and verify RED**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests/test_internal_test_access.py -q`

Expected: FAIL because `app.services.internal_test_access` does not exist.

- [ ] **Step 3: Implement backend-only whitelist parsing and settings**

Add `INTERNAL_TEST_CODE=121212`, `INTERNAL_TEST_PHONES`, and `INTERNAL_TEST_PHONES_FILE` settings and compose pass-through. Implement normalized CSV/file membership without logging phone lists or codes.

- [ ] **Step 4: Write failing admission metadata tests**

Add cases proving whitelist bypass creates `admission_type="whitelist"` in invite-only mode and that returned count/target are copied from the locked invitation program.

- [ ] **Step 5: Run admission tests and verify RED**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests/test_invitation_registration.py -q`

Expected: FAIL because `whitelist_bypass` and metadata fields are absent.

- [ ] **Step 6: Extend admission issuance and verify GREEN**

Add the optional bypass after existing-user detection and before registration-mode rejection. Return program counts and admission type from the existing locked transaction.

- [ ] **Step 7: Run Task 1 tests**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests/test_internal_test_access.py dazi-server/tests/test_invitation_registration.py dazi-server/tests/test_beta_signup_static.py -q`

Expected: all pass.

### Task 2: Hybrid Send And Login Routes

**Files:**
- Modify: `dazi-server/app/api/auth.py`
- Modify: `dazi-server/app/api/schemas.py`
- Test: `dazi-server/tests/test_sms_auth_api.py`
- Test: `dazi-server/tests/test_auth_schemas.py`

**Interfaces:**
- Produces successful `AuthSendCodeResponse` fields `user_state`, `invitation_state`, `qualified_user_count`, and `qualified_target`.
- Produces structured `403` detail with `code="invitation_required"`, `invitation_state="required"`, and actual counts.
- Consumes Task 1 whitelist helpers and admission metadata.

- [ ] **Step 1: Write failing send-code branch tests**

Cover existing, whitelist, new-open, new-invite-required, and new-valid-invite branches. Assert real SMS is called exactly once only when admission succeeds and never for the missing-invite branch.

- [ ] **Step 2: Run send-code tests and verify RED**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests/test_sms_auth_api.py -q`

Expected: FAIL because whitelist bypass and response metadata are absent.

- [ ] **Step 3: Implement send-code classification**

Pass `whitelist_bypass` into admission issuance, map admission type to `user_state` and `invitation_state`, and include actual policy counts in success and invitation-required responses before invoking rate limiting or the SMS provider.

- [ ] **Step 4: Write failing hybrid login tests**

Assert a whitelisted `121212` login never calls PNVS, a whitelist dynamic code calls PNVS and succeeds, and a non-whitelist `121212` is accepted only when PNVS independently verifies it. Assert a new whitelist fixed-code login may create an account without an admission token while new non-whitelist logins still require one.

- [ ] **Step 5: Run login tests and verify RED**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests/test_sms_auth_api.py -q`

Expected: FAIL because login always calls PNVS and new users always require admission.

- [ ] **Step 6: Implement hybrid login and verify GREEN**

Use the fixed-code helper first. Call PNVS only when it returns false. Permit the no-token new-user path only when fixed-code verification succeeded; preserve admission consumption for all other new users.

- [ ] **Step 7: Run Task 2 tests**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests/test_sms_auth_api.py dazi-server/tests/test_auth_schemas.py -q`

Expected: all pass.

### Task 3: iOS Invitation Field State

**Files:**
- Modify: `dazi/Services/APIClient.swift`
- Modify: `dazi/Views/Onboarding/LoginView.swift`
- Test: `tests/test_login_verification_static.py`
- Test: `tests/test_invitation_ios_static.py`

**Interfaces:**
- Consumes send-code metadata from Task 2.
- Produces Swift `LoginInvitationState.hidden`, `.notRequired(target: Int)`, and `.required(target: Int)`.

- [ ] **Step 1: Write failing iOS contract tests**

Assert Codable mappings for the new response fields and structured API error detail. Assert one invitation-field builder handles both disabled gray and enabled input states, and that display copy interpolates the backend target rather than a literal number.

- [ ] **Step 2: Run iOS tests and verify RED**

Run: `python3 -m unittest tests.test_login_verification_static tests.test_invitation_ios_static`

Expected: FAIL because metadata and invitation states are absent.

- [ ] **Step 3: Implement response and error decoding**

Add optional Codable fields for backward compatibility. Add typed server-detail parsing without changing the generic request error contract for unrelated endpoints.

- [ ] **Step 4: Implement the shared invitation field**

Keep the field hidden initially. On new-open success show a disabled gray field containing `前 \(target) 位用户免邀请码`; on structured invitation-required error show the same field enabled and retain the existing normalized invite value. Existing and whitelist success hide it.

- [ ] **Step 5: Run Task 3 tests and build**

Run: `python3 -m unittest tests.test_login_verification_static tests.test_invitation_ios_static`

Run: `xcodebuild -project dazi.xcodeproj -scheme dazi -destination 'generic/platform=iOS Simulator' build`

Expected: tests pass and build ends with `** BUILD SUCCEEDED **`.

### Task 4: Regression And Deployment Readiness

**Files:**
- Verify only; do not modify unrelated dirty files.

**Interfaces:**
- Consumes all prior task outputs.
- Produces test and production-readiness evidence.

- [ ] **Step 1: Run the complete backend suite**

Run: `dazi-server/.venv311/bin/python -m pytest dazi-server/tests -q`

Expected: all tests pass.

- [ ] **Step 2: Run root iOS tests and diff checks**

Run: `python3 -m unittest discover tests`

Run: `git diff --check`

Expected: all tests pass and diff check exits zero.

- [ ] **Step 3: Verify production configuration presence without printing secrets**

Confirm the production environment defines Aliyun PNVS credentials, enables PNVS, sets the fixed code, and provides a whitelist source. Report only SET/UNSET status.

- [ ] **Step 4: Review scoped diff**

Confirm no Android files changed, no secrets entered git, `N` is never hardcoded in iOS, and unrelated user changes remain intact.
