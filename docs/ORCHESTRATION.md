# V1 Orchestration

## 1. System Boundary

```text
                    ┌──────────────────────────┐
                    │       Your Backend       │
                    │ auth / subscription /    │
                    │ flags / aggregate stats  │
                    └─────────────▲────────────┘
                                  │
                     no gallery content
                                  │
┌─────────────────────────────────┴────────────────────────────────┐
│                            PHONE                                │
│                                                                │
│  Gallery → Scan → Features → AI → Personal Model → Suggestions │
│                                         ↓                      │
│                                   User Review                  │
│                                         ↓                      │
│                                  OS Deletion API               │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## 2. Local Scan Orchestrator

State machine:

```text
IDLE
  ↓
DISCOVER_ASSETS
  ↓
DIFF_LOCAL_INDEX
  ↓
FAST_ANALYSIS
  ↓
SEMANTIC_ANALYSIS
  ↓
CLUSTERING
  ↓
PERSONAL_PREDICTION
  ↓
UPDATE_INSIGHTS
  ↓
COMPLETE
```

Failure states:
- PAUSED
- CANCELLED
- PARTIAL
- FAILED

A later run resumes from persisted scan state.

## 3. Stage 1 — Discover Assets

Input:
OS media library.

Process:
- enumerate accessible media,
- collect only required metadata,
- compare with local asset index,
- mark missing assets,
- enqueue new/changed assets.

Do not load full-resolution media here.

## 4. Stage 2 — Fast Analysis

Run inexpensive analysis first:

- media type,
- size,
- screenshot metadata/heuristics,
- thumbnail generation/access,
- exact hash where feasible,
- perceptual hash,
- blur score,
- brightness/quality score.

Outputs are persisted locally.

## 5. Stage 3 — Semantic Analysis

For assets requiring deeper analysis:

```text
thumbnail / reduced image
        ↓
on-device embedding model
        ↓
embedding vector
        ↓
category similarity
        ↓
local feature cache
```

Never transmit the embedding.

## 6. Stage 4 — Clustering

Suggested pipeline:

```text
Exact hash
   ↓
Exact duplicate groups

Perceptual hash candidate search
   ↓
Near-duplicate candidates

Embedding similarity
   ↓
Similar-image groups

Capture-time proximity + similarity
   ↓
Burst/event groups
```

Avoid O(n²) comparison across the entire gallery.

Use:
- hash buckets,
- candidate prefiltering,
- approximate-nearest-neighbor strategy if needed.

## 7. Stage 5 — Personal Preference Prediction

Feature vector may contain:

```text
semantic embedding
blur score
quality score
screenshot flag
category scores
media age bucket
file size bucket
favorite state
duplicate/similarity context
```

Prediction:

```text
deleteProbability
confidence
reasonCodes
```

Do not use local filename or OCR text as required personal-model features in V1.

## 8. Swipe Training Orchestrator

Candidate pool priority:

```text
1. uncertain personal predictions
2. high-storage-value items
3. common cleanup categories
4. balanced semantic categories
5. new model-version samples
```

User action:

```text
KEEP
DELETE
SKIP
```

Flow:

```text
Decision
  ↓
Persist locally
  ↓
Update training-example count
  ↓
If update threshold reached
     retrain/update tiny personal model
  ↓
Invalidate affected predictions
  ↓
Re-score background candidates
```

Recommended retrain trigger:
- every 10–25 new explicit labels,
- or at session end,
- whichever is cheaper.

## 9. Smart Batch Orchestrator

Candidate sources:
- exact duplicates,
- near duplicates,
- blurry images,
- screenshots,
- large videos,
- personalized high-delete-probability items.

Safety filter:

```text
Candidate
  ↓
Is deterministic duplicate?
  ├─ yes → eligible
  └─ no
      ↓
Does model have enough training samples?
  ├─ no → review feed only
  └─ yes
      ↓
Is delete confidence above configured threshold?
  ├─ no → review feed
  └─ yes → smart batch candidate
```

Batch creation must store:
- local asset ID,
- reason code,
- confidence,
- reclaimable bytes,
- selected-by-default state.

The user reviews the final batch.

## 10. Deletion Orchestrator

```text
Reviewed batch
  ↓
User confirms
  ↓
Revalidate asset existence
  ↓
Request platform deletion
  ↓
OS confirmation
  ↓
Per-item result
  ├─ success
  ├─ failed
  └─ skipped
  ↓
Update local DB
  ↓
Update profile aggregates
  ↓
Queue aggregate telemetry
```

Never preemptively remove records before OS confirmation.

## 11. Profile / Insights Orchestrator

Profile is generated from local aggregates.

Examples:

```text
totalAssets
totalPhotos
totalVideos
totalStorageBytes
screenshotsPercent
categoryDistribution
keepDeleteRatio
categoryKeepRate
categoryDeleteRate
itemsReviewed
bytesReclaimed
personalTrainingSamples
```

Charts read only aggregate local values.

The backend does not need category-distribution details for V1.

## 12. Subscription Orchestration

```text
App launch
   ↓
Read cached entitlement
   ↓
Render immediately
   ↓
Refresh RevenueCat entitlement
   ↓
Sync backend entitlement mirror
   ↓
Update feature gates
```

Offline:
- allow a reasonable cached entitlement grace window,
- do not permanently unlock premium based on an editable local flag.

## 13. Telemetry Orchestration

```text
Local product event
  ↓
Convert to approved aggregate schema
  ↓
Privacy filter
  ↓
Local telemetry queue
  ↓
Network available?
  ├─ no → retain
  └─ yes
      ↓
Batch upload
      ↓
Server validates allowlist
      ↓
Persist aggregate event
```

Privacy filter must reject unknown fields.

## 14. Background Work

Eligible:
- incremental scan,
- hash generation,
- feature extraction,
- prediction refresh,
- profile aggregate refresh.

Constraints:
- respect Android/iOS background execution limits,
- pause under battery/thermal pressure,
- prefer foreground processing for long initial scans,
- show progress,
- support cancellation.

## 15. Cold Start Orchestration

Immediately after install:

```text
Gallery permission
  ↓
Fast local scan
  ↓
Deterministic cleanup available
  ↓
User performs first swipe session
  ↓
Collect explicit labels
  ↓
Personal model activates progressively
```

Do not pretend personalization exists before enough labels are available.

## 16. Model Version Update

When generic embedding model changes:

```text
Remote config announces model version
  ↓
Download/ship model asset safely
  ↓
Keep old feature cache valid until replacement exists
  ↓
Incrementally recompute embeddings
  ↓
Rebuild affected similarity clusters
  ↓
Retrain personal classifier if feature dimensions changed
```

Avoid forcing a full gallery re-scan on app launch.

## 17. Local vs Remote Responsibility Matrix

| Responsibility | Local Device | Backend |
|---|---:|---:|
| Gallery access | Yes | No |
| Photos/videos | Yes | No |
| Embeddings | Yes | No |
| Duplicate detection | Yes | No |
| Semantic categories | Yes | No |
| Keep/Delete history | Yes | No |
| Personal model | Yes | No |
| Cleanup batches | Yes | No |
| Actual deletion | Yes | No |
| Profile gallery stats | Yes | No |
| Account | No | Yes |
| Subscription | Cached | Yes |
| Feature flags | Cached | Yes |
| Aggregate telemetry | Queue | Yes |
| Raw gallery analytics | No | No |

## 18. Recommended Build Sequence

```text
M0 Foundation
→ M1 Local Gallery
→ M2 Deterministic Cleaner
→ M3 Semantic Embeddings
→ M4 Swipe Learning
→ M5 Personal Model
→ M6 Smart Batch
→ M7 Profile/Insights
→ M8 Auth/Subscription/Telemetry
→ M9 Performance + Privacy Audit
→ V1 Release
```
