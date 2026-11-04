# V1 Engineering Rules

These rules are mandatory unless explicitly changed by the product owner.

## 1. Privacy Rules

1. Gallery media never leaves the device.
2. Never upload originals, thumbnails, embeddings, OCR text, filenames, album names, EXIF location, or per-photo labels.
3. Personal Keep/Delete decisions remain local.
4. Personal model weights remain local.
5. No third-party analytics SDK may receive gallery identifiers or gallery-derived content.
6. Crash logs must be scrubbed of local media paths and user content.
7. Any future feature requiring media upload must be separately designed and explicitly opt-in. It is not part of V1.

## 2. Deletion Rules

1. No automatic silent deletion.
2. Every deletion batch must be visible before execution.
3. User can deselect any proposed item.
4. Prefer platform trash/recycle-bin APIs when available.
5. If deletion partially fails, never retry destructively without user awareness.
6. Do not mark an item as deleted until the OS confirms success.

## 3. Architecture Rules

1. Flutter is the primary UI/application framework.
2. Use platform-native code only where required for performance or OS-specific media behavior.
3. Client owns all gallery processing.
4. Server must remain ignorant of gallery contents.
5. Local DB is the source of truth for analysis state.
6. Remote DB is the source of truth for account/subscription state.
7. Every model and feature extractor must have a version identifier.
8. All long-running media work must be cancellable and resumable.
9. Do not block the main UI isolate with image hashing or model inference.

## 4. Model Rules

1. Do not train a large vision model from scratch for V1.
2. Use deterministic methods when they solve the task better than AI.
3. Use AI only for semantic/similarity/personalization tasks where it adds value.
4. Confidence must be stored with model predictions.
5. Low-confidence predictions should become review candidates, not deletion candidates.
6. The model must be allowed to abstain.
7. User override always wins.
8. Personal-model training must not require a network connection.

## 5. Feature Scope Rules

V1 contains only:
- Gallery
- Smart Cleaner
- Swipe Training
- Smart Batch Suggestions
- Profile / Insights
- Subscription and account infrastructure

Any feature outside this list requires explicit approval.

## 6. Data Minimization Rules

Server telemetry should use aggregates.

Allowed examples:
- `items_scanned_delta = 200`
- `items_reviewed_delta = 15`
- `items_deleted_delta = 8`
- `storage_saved_mb_delta = 431`
- `session_duration_bucket = "2-5m"`

Disallowed examples:
- local media ID,
- photo filename,
- image embedding,
- category sequence tied to individual files,
- text extracted from screenshots,
- GPS coordinates.

## 7. Performance Rules

1. Thumbnail-first processing.
2. Decode full-resolution images only when strictly necessary.
3. Cache derived features locally.
4. Recompute only when:
   - asset changed,
   - model version changed,
   - cache invalidated.
5. Batch inference where supported.
6. Throttle work on low battery / thermal pressure.
7. Pause heavy scanning when OS background policies require it.

## 8. Offline Rules

Core app functionality must work offline:
- gallery,
- scan,
- duplicate detection,
- categorization,
- swipe training,
- personal model,
- cleanup suggestions,
- profile statistics.

Network is only required for:
- auth,
- subscription verification,
- remote config,
- aggregate telemetry sync.

## 9. UX Safety Rules

1. Never use manipulative wording to pressure deletion.
2. Clearly distinguish:
   - duplicate,
   - low-quality,
   - AI suggestion.
3. Do not display AI confidence as certainty.
4. User should always understand why an item was suggested.
5. Preserve user control at every destructive step.

## 10. Code Quality Rules

1. Null-safe Dart only.
2. Strongly typed API models.
3. Repository pattern for remote/local data boundaries.
4. Service interfaces must be mockable.
5. No business logic inside widgets.
6. No direct SQLite queries from presentation layer.
7. No direct API calls from UI widgets.
8. Use feature modules.
9. All destructive actions require tests.
10. Privacy invariants require automated tests.

## 11. Suggested Flutter Structure

```text
lib/
  app/
  core/
    auth/
    config/
    database/
    networking/
    privacy/
    subscriptions/
    telemetry/
  features/
    onboarding/
    gallery/
    cleaner/
    swipe_training/
    smart_batch/
    profile/
    settings/
  ml/
    embeddings/
    similarity/
    quality/
    classifier/
    personalization/
    orchestration/
  platform/
    media/
    deletion/
    background/
```

## 12. Forbidden Shortcuts

Do not:
- upload photos "temporarily" for easier AI,
- use a server LLM to classify user media,
- use raw file paths as analytics IDs,
- bypass OS deletion confirmation,
- make premium entitlement dependent only on a local boolean,
- silently change the privacy contract.
