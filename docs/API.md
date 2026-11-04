# V1 Backend API Contract

## 1. Principles

The API exists for:
- authentication,
- subscription entitlement,
- remote configuration,
- feature flags,
- aggregate telemetry,
- account lifecycle.

The API must never accept gallery media or gallery-derived sensitive content.

Base path:

```text
/api/v1
```

JSON only.

## 2. Authentication

Recommended:
- short-lived access token,
- refresh-token/session mechanism,
- provider-backed auth through Supabase Auth or equivalent.

Every authenticated endpoint resolves:
- `user_id`,
- `install_id`,
- platform/app version headers.

Suggested headers:

```text
Authorization: Bearer <token>
X-Install-ID: <uuid>
X-App-Version: 1.0.0
X-Platform: android|ios
```

## 3. Privacy Enforcement

Server must reject requests containing forbidden keys such as:

```text
photo
image
thumbnail
embedding
filename
filepath
local_asset_id
ocr_text
latitude
longitude
exif
face_embedding
```

This is defense-in-depth, not the primary privacy mechanism.

## 4. Endpoints

### POST /auth/bootstrap

Purpose:
Initialize account/session state after sign-in.

Response:

```json
{
  "user": {
    "id": "uuid",
    "createdAt": "2026-09-20T10:00:00Z"
  },
  "entitlements": {
    "premium": false
  },
  "configVersion": "v1.3"
}
```

### GET /me

Response:

```json
{
  "id": "uuid",
  "accountStatus": "active",
  "createdAt": "2026-09-20T10:00:00Z"
}
```

### DELETE /me

Deletes backend account/business data according to policy.

Must not imply deletion of device gallery data because gallery data is local.

### POST /devices/register

Request:

```json
{
  "installId": "uuid",
  "platform": "android",
  "osVersion": "16",
  "appVersion": "1.0.0",
  "deviceClass": "phone"
}
```

Response:

```json
{
  "ok": true
}
```

### GET /config

Returns:
- model configuration version,
- feature flags,
- review limits,
- confidence thresholds,
- optional rollout values.

Example:

```json
{
  "version": "v1.3",
  "features": {
    "personalizedBatch": true,
    "largeVideoCleaner": true
  },
  "limits": {
    "freeDailyReviews": 50
  },
  "ml": {
    "personalModelMinSamples": 25,
    "highConfidenceDeleteThreshold": 0.90
  }
}
```

Do not send raw model weights through this endpoint unless they are generic public model assets.

### GET /entitlements

Response:

```json
{
  "premium": {
    "active": true,
    "productId": "premium_monthly",
    "expiresAt": "2026-10-20T00:00:00Z"
  }
}
```

### POST /subscriptions/webhook/revenuecat

Server-to-server endpoint.

Responsibilities:
- verify webhook authenticity,
- map provider customer to user,
- update entitlement,
- handle renewals,
- cancellations,
- expiration,
- refunds.

This endpoint is not called by the mobile client.

### POST /telemetry/batch

Accepts only allowlisted aggregate events.

Request:

```json
{
  "events": [
    {
      "eventId": "uuid",
      "name": "cleanup_completed",
      "version": 1,
      "occurredAt": "2026-09-20T10:00:00Z",
      "metrics": {
        "itemsDeleted": 18,
        "storageSavedMb": 742
      }
    },
    {
      "eventId": "uuid",
      "name": "swipe_session_completed",
      "version": 1,
      "occurredAt": "2026-09-20T10:04:00Z",
      "metrics": {
        "itemsReviewed": 20,
        "keepCount": 13,
        "deleteCount": 5,
        "skipCount": 2
      }
    }
  ]
}
```

Response:

```json
{
  "accepted": 2,
  "rejected": 0
}
```

### GET /usage/today

Useful for quota display.

Response:

```json
{
  "date": "2026-09-20",
  "itemsReviewed": 31,
  "freeDailyReviewLimit": 50
}
```

## 5. Allowed Telemetry Events

V1 allowlist:

```text
app_opened
onboarding_completed
permission_state_changed
scan_started
scan_completed
swipe_session_started
swipe_session_completed
cleanup_batch_reviewed
cleanup_completed
subscription_paywall_viewed
subscription_started
subscription_restored
profile_viewed
error_aggregate
```

## 6. Forbidden API Endpoints

Do not create:

```text
POST /photos
POST /gallery/upload
POST /embeddings
POST /classify-image
POST /sync/gallery
POST /sync/preferences
```

## 7. Idempotency

Use `eventId` or `Idempotency-Key` for:
- telemetry batch inserts,
- subscription events,
- account mutation endpoints where relevant.

The server must safely tolerate retries.

## 8. Error Format

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Request failed validation",
    "requestId": "uuid"
  }
}
```

Never return stack traces to production clients.

## 9. Rate Limits

Suggested:
- config: 60/hour/install,
- telemetry: 30 batches/hour/install,
- auth/bootstrap: 30/hour/user,
- account deletion: strict abuse protection.

## 10. API Versioning

Breaking changes require a new base version.

Telemetry event schemas are individually versioned.

## 11. Subscription Authority

The trusted order should be:

```text
App Store / Google Play
        ↓
RevenueCat
        ↓
Backend entitlement mirror
        ↓
Mobile app
```

Local cached entitlement is allowed for temporary offline UX but must not be treated as permanent authority.
