# Implementation notes

This repository began with docs only. No backend or mobile app was present. The V2 PRD was copied into docs/PRD.md without changing its content.

## Local boundaries

GalleryRepository separates device access from the explicit sample library. Conditional imports keep native file/database/plugin paths out of the browser app. The browser uses its own sample-only local storage key. Native demo and real libraries use different SQLite database files.

The native SQLite schema is version 2. `local_state` holds small metadata and `local_features` stores one JSON feature row per media ID. Saves are transactional and controller writes are serialized. Browser state uses IndexedDB state, feature and media stores and patches only changed feature rows. Face embeddings live in the same local feature rows as other derived analysis. Turning People off clears these rows' face fields and native storage is compacted. The schema is still not benchmarked on a very large library.

No gallery network client or telemetry service is configured. The Android release manifest has no INTERNET permission. Browser preview requests are limited to same-origin app resources and local user-selected photo files never go to the server. Bundled TinyCLIP, YuNet and SFace inference uses ONNX Runtime. The browser path resolves packaged model assets under Flutter's `assets/assets/models` prefix; native asset loading uses the regular Flutter asset keys.

## Deletion sequence

1. Display the candidate items and reasons. No selection is preapproved.
2. User selects/deselects specific items.
3. In-app confirmation describes item count, estimated bytes and platform behavior.
4. Persist an audit intent before making any OS request. If persistence fails, do not call the OS.
5. Revalidate native IDs and invoke the platform deletion API.
6. Use only returned success IDs, intersected with the reviewed set, to remove local features, timestamps, decisions and queue entries.
7. Increment saved bytes only for confirmed successes. Keep failures unchanged. Persist the outcome.

If the app dies after the OS request but before the outcome save, the requested audit entry remains unresolved. The next library refresh prunes unavailable local assets, but does not invent reclaimed-byte totals. Full interrupted-operation reconciliation is still required before production release. A confirmation sheet alone is not proof of deletion.

## Scans

The native pipeline checks original availability before file access, skips cloud-only originals, streams original bytes into SHA-256, and decodes reduced thumbnails for dHash and Laplacian variance in a worker isolate. TinyCLIP supplies normalized 512-value image embeddings and prompt-category scores. YuNet/SFace runs only while opt-in People grouping is enabled; video items are skipped. The browser uses actual image pixels from its sample or imported local copies. Similarity and face thresholds are heuristic and need larger-set validation. Best shot still means favorite first, then higher thumbnail sharpness.

Only changed/uncached/extractor-version-mismatched items are analyzed. Each item is checkpointed. Pause is cooperative at item boundaries, so a very large file hash can finish before pausing. There is no background service or resumable process cursor beyond the per-item cache. OS/library changes are refreshed on resume and by the Refresh action.

Screenshot hints use the Apple screenshot subtype or a screenshot-like filename, without a dimensions-only guess that would confuse normal portrait photos. Filenames are inspected locally and are not stored or transmitted.

## Native verification still needed

- Android SDK/Gradle compilation, iOS Xcode compilation and signing.
- ONNX inference parity, memory, scan time, battery and thermal behavior on current iOS and Android phones.
- Permissions: denied, limited, expanded, revoked; system-selected photos on Android 14+.
- Confirm/cancel deletion, partial failure, interrupted requests and Recently Deleted behavior on each OS/version.
- HEIC, Live Photos, edited originals, large video files, cloud-only assets and supported codecs.
- SQLite backup exclusion on backup/restore, release manifest merged permissions and plugin behavior.
- Background interruptions, thermal/battery behavior and measured large-library memory/scan timing.
- Native screenshots, back gestures, reduced motion and screen-reader behavior.

Browser screenshots and Flutter widget tests provide preview/layout evidence only. They are not native device captures.
