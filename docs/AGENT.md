# AGENT.md

## Mission

Build V1 of a privacy-first Flutter gallery cleaner that performs all gallery analysis and personalized AI learning on-device.

## Product Invariant

**User gallery media must never leave the device.**

Treat this as a hard architectural constraint, not a preference.

## Read Before Coding

Before implementing any task:
1. Read `PRD.md`.
2. Read `RULES.md`.
3. Read `database_schema.sql`.
4. Read `API.md`.
5. Read `ORCHESTRATION.md`.
6. Inspect existing code before introducing new abstractions.

## Technology Defaults

Client:
- Flutter
- Dart
- `photo_manager` or equivalent for media-library access
- SQLite/Drift or SQLite wrapper for local persistence
- Riverpod, Bloc, or equivalent predictable state management
- local notifications
- native Kotlin/Swift bridges only when required

On-device ML:
- perceptual hash for duplicates/similarity prefilter
- deterministic blur/quality metrics
- lightweight pretrained image embedding model such as MobileCLIP-compatible or equivalent
- local linear/logistic classifier for personalization

Backend:
- REST/JSON
- PostgreSQL
- Supabase or equivalent is acceptable
- RevenueCat or equivalent for entitlement orchestration

## Agent Operating Rules

### Do
- prefer deterministic algorithms over ML when possible,
- keep expensive work off the UI isolate,
- persist derived local features,
- make scans resumable,
- write migrations for schema changes,
- make destructive operations idempotent,
- add tests for cleanup/deletion workflows,
- add explicit model/version fields to cached AI output,
- preserve user override history locally.

### Never
- upload a photo,
- upload a thumbnail,
- upload an image embedding,
- upload OCR contents,
- upload local file paths,
- upload GPS/EXIF location,
- upload per-photo keep/delete decisions,
- store personal model weights remotely,
- auto-delete without final user approval.

## Implementation Order

### Phase 1 — Foundation
- Flutter app shell
- permissions
- media library access
- local database
- repository interfaces
- background task abstraction

### Phase 2 — Deterministic Cleaner
- exact hash
- perceptual hash
- duplicate grouping
- screenshot detection
- blur score
- file-size analysis
- large-video detection

### Phase 3 — Semantic Intelligence
- on-device embedding extraction
- similarity clustering
- semantic category scoring
- local feature cache

### Phase 4 — Swipe Training
- Keep/Delete/Skip actions
- local label storage
- training dataset builder
- cold-start behavior
- personal model update

### Phase 5 — Smart Batch
- candidate ranking
- confidence thresholds
- explanation generation
- review screen
- OS deletion
- audit record

### Phase 6 — Profile
- category distribution
- cleanup statistics
- space saved
- Keep/Delete tendencies
- AI learning progress

### Phase 7 — Account / Subscription
- auth
- backend sync
- RevenueCat entitlement mapping
- feature gating
- aggregate telemetry

## Decision Hierarchy

When deciding whether to suggest deletion:

1. Hard deterministic signals
2. Duplicate/similarity evidence
3. Media-quality evidence
4. Semantic category
5. Personal model
6. Confidence threshold
7. User review

User review is always final.

## Personal Model Interface

The implementation should expose an abstraction similar to:

```dart
abstract interface class PersonalPreferenceModel {
  Future<void> load();
  Future<PreferencePrediction> predict(MediaFeatureVector vector);
  Future<void> update(List<LabeledMediaFeatureVector> samples);
  Future<void> reset();
  String get modelVersion;
}
```

A prediction should contain:

```text
deleteProbability
confidence
modelVersion
reasonCodes[]
```

Do not bind the app to one ML implementation.

## Telemetry Contract

Before adding a telemetry field ask:

> Can this field reveal what is actually inside the user's gallery?

If yes, do not send it.

All telemetry calls must pass through one privacy-filtered telemetry service.

## Deletion Contract

Deletion service must:
1. receive reviewed local asset IDs,
2. revalidate asset existence,
3. request OS deletion,
4. capture per-item success/failure,
5. update local records only after confirmation,
6. update aggregate storage-saved stats,
7. emit only aggregate telemetry.

## Testing Requirements

Minimum automated test coverage should include:
- duplicate grouping,
- similarity thresholds,
- screenshot detection fallback,
- local model training,
- model cold start,
- confidence gating,
- batch selection/deselection,
- deletion partial failure,
- entitlement gating,
- telemetry privacy allowlist,
- local schema migrations.

## UI / Design

The final design is intentionally not defined yet.

Do not invent a permanent visual design system.

Build screens using replaceable presentation components and stable domain interfaces so future design changes do not affect the ML/data architecture.

## Definition of Done

A task is done only when:
- implementation works,
- tests are included where applicable,
- privacy rules are satisfied,
- no gallery content is transmitted,
- failure states are handled,
- local schema/API changes are documented.
