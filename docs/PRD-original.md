Product Requirements Document — V2
On-Device AI Gallery Cleaner with Smart Categorization and People Grouping
1. Product Summary
A privacy-first mobile gallery cleaner that helps users review, organize, and safely remove unwanted media. All analysis, including categorization, similarity detection, and face grouping, runs on the device. The app learns each user's personal keep/delete preferences locally.
The app combines:
• deterministic cleanup (hashes, blur, metadata),
• on-device semantic analysis (MobileCLIP embeddings),
• on-device people grouping (face detection, face embeddings, clustering),
• swipe-based preference learning,
• batch cleanup recommendations,
• profile and gallery insights,
• subscription-gated premium features.
Core product promise:
The user's gallery never leaves the device.
2. Product Goal
Help users reduce gallery clutter and reclaim storage without long manual cleanup sessions and without uploading private media to any server or third-party AI API.
The system improves over time by learning from explicit user decisions.
3. What Changed From V1
• The AI stack is now defined: MobileCLIP for categorization, similarity and personal-model features; ML Kit Face Detection plus MobileFaceNet for people grouping.
• People grouping (face clustering) is now a V2 feature. It was a non-goal in V1.
• No cloud LLM or vision API is used. Per-photo cloud cost is zero.
• Face embeddings and person clusters are stored only on the device and are covered by the privacy invariant.
4. V2 Product Pillars
4.1 Gallery
A gallery browser backed by the device photo library.
• display photos and videos,
• paginate efficiently,
• support albums,
• show basic metadata needed for cleanup,
• update when the device gallery changes,
• never create a server-side mirror.
4.2 Smart Cleaner
Detect and group media into actionable cleanup categories.
Cleanup categories:
• exact duplicates,
• near duplicates,
• similar/burst photos (with best-shot suggestion),
• screenshots,
• blurry/low-quality photos,
• large videos,
• personalized AI cleanup suggestions.
Semantic categories (assigned by MobileCLIP zero-shot text prompts, used for filtering, insights and model features):
• selfie,
• people/group,
• food,
• pet,
• travel,
• nature,
• document,
• receipt,
• meme,
• product,
• other.
The category list is defined by editable text prompts in app config, so categories can be added or tuned without retraining a model.
4.3 People Grouping
Group photos by the people in them, fully on-device.
Requirements:
• detect faces in photos with ML Kit Face Detection,
• crop each detected face and compute a face embedding with MobileFaceNet,
• cluster face embeddings locally (cosine similarity with threshold, or DBSCAN),
• show people groups as anonymous clusters ("Person 1", "Person 2"),
• let the user optionally rename a cluster locally,
• let the user merge clusters, split a cluster, or remove a face from a cluster,
• use people groups as cleanup context (for example, review all photos of one person, or find the best shot among similar photos of the same person),
• provide a setting to disable people grouping and delete all face data and clusters,
• run the face embedding step only on photos where face detection finds at least one face.
Face data (crops, embeddings, clusters, names) never leaves the device and is never included in telemetry.
4.4 Swipe Training
A lightweight review experience.
Each item or group can receive:
• Keep
• Delete
• Skip / Not sure
Each explicit decision becomes local preference-training data.
The feed prioritizes:
1. high-value cleanup candidates,
2. uncertain examples that improve the personal model,
3. a balanced sample of categories to avoid overfitting.
4.5 Smart Batch Suggestions
The app creates reviewable cleanup batches based on:
• deterministic rules,
• similarity groups,
• file size,
• media quality,
• personal delete probability,
• model confidence.
The user must see the proposed items before deletion. No media may be deleted solely because an AI model predicted deletion.
4.6 Profile / Insights
User-facing aggregate statistics:
• total photos and videos,
• gallery storage,
• category distribution,
• screenshots percentage,
• keep/delete behavior,
• space saved,
• items reviewed,
• cleanup streak/activity,
• AI learning progress,
• category-specific keep/delete tendencies,
• number of people groups found (count only, no names or faces in aggregate telemetry).
Charts may use pie, donut, bar, or radial visualizations. The profile must not imply psychological traits or sensitive characteristics.
5. Privacy Invariant
The following must never be uploaded:
• original photos,
• original videos,
• thumbnails and face crops,
• image embeddings,
• face embeddings and person clusters,
• person names or labels,
• OCR output containing user content,
• EXIF location,
• gallery filenames,
• raw album names unless explicitly required and consented,
• per-photo keep/delete history,
• personal preference model weights.
No gallery content is sent to any third-party AI or vision API.
Allowed server-side data is restricted to:
• account identity,
• subscription state,
• app/device metadata,
• feature flags,
• coarse aggregate usage telemetry,
• aggregate storage saved,
• aggregate item counts,
• crash/error telemetry that does not contain gallery content.
6. Users
Primary user: a smartphone owner with a large, cluttered gallery who wants a quick, private way to clean it.
Secondary user: a storage-conscious user who accumulates screenshots, duplicates, bursts, and large videos.
7. User Stories
Onboarding
• I can grant photo-library permissions.
• I can understand that processing stays on my device.
• I can choose whether to enable people grouping.
• I can choose whether to enable notifications.
Cleaner
• I can see duplicate groups and similar-photo groups.
• I can see a suggested best shot in each similar group.
• I can review screenshots and blurry images.
• I can see large videos sorted by reclaimable storage.
• I can filter photos by category (food, document, receipt, and so on).
People
• I can browse photos grouped by person.
• I can rename, merge, or split people groups.
• I can turn off people grouping and delete all face data.
Learning
• I can swipe Keep/Delete/Skip.
• I can see that the AI is learning from my decisions.
• I can override every recommendation.
Batch Cleanup
• I can review a proposed cleanup batch.
• I can deselect individual items.
• I can approve deletion only after review.
Profile
• I can see how my gallery is distributed.
• I can see how much storage I saved.
• I can see category-specific keep/delete tendencies.
Subscription
• I can use a free tier.
• I can upgrade to premium.
• My entitlement restores across supported devices through the store/subscription provider.
8. Free vs Premium — Proposal
Free
• gallery browsing,
• exact duplicate detection,
• screenshot cleanup,
• blur detection,
• basic category filters,
• basic swipe review with a limited daily smart-review quota,
• basic profile statistics.
Premium
• unlimited smart review,
• personalized preference learning beyond the free quota,
• smart batch recommendations,
• advanced similarity grouping and best-shot suggestions,
• people grouping,
• large-video cleanup,
• advanced profile/insight metrics,
• scheduled cleanup prompts.
Exact pricing is excluded from engineering scope.
9. AI / ML Requirements
9.1 On-Device Model Stack
V2 uses pretrained on-device components only. No models are trained from scratch and no cloud inference is used.
Purpose
Component
Runtime
Semantic embedding, zero-shot categories, similarity
MobileCLIP (int8 quantized)
tflite_flutter
Face detection and cropping
google_mlkit_face_detection
ML Kit
Face embedding
MobileFaceNet (int8 quantized)
tflite_flutter
Personal keep/delete model
Logistic regression (local)
Dart / local
Exact duplicates
File hash
Dart
Near duplicates and bursts
Perceptual hash plus timestamp proximity
Dart
Blur
Laplacian variance
Dart
Screenshots and large videos
Dimensions, metadata, file size
Dart
A single runtime (tflite_flutter) serves both neural models to keep the app lightweight. Feature extraction sits behind an interface so a model can be swapped without changing the pipeline.
Before release, confirm that the license of each pretrained model allows commercial use in a mobile app.
9.2 Feature Pipeline
Each local asset may generate:
• media type,
• width/height,
• duration,
• size,
• creation age,
• favorite state if available,
• screenshot signal,
• blur score,
• brightness/exposure score,
• perceptual hash,
• file hash,
• MobileCLIP embedding,
• semantic category scores,
• duplicate/similarity cluster ID,
• face count and per-face quality (eyes open, smiling, centered),
• face embeddings and person cluster IDs,
• personal keep/delete probability,
• confidence score.
9.3 Scan Behavior
• Scan runs locally in the background in batches.
• Prefer running heavy scans while the device is charging, with a user override.
• Every result is cached locally, and only new or changed assets are processed afterward.
• The scan is pausable and resumable.
• The app shows scan progress and never blocks browsing while scanning.
• Performance targets (to be validated on real devices): scan 1,000 photos in a few minutes on a recent mid-range phone, without noticeable battery or thermal impact.
9.4 Personal Model
A lightweight local binary classifier predicts:
P(delete | local media features + MobileCLIP embedding + user history)
Starting model: logistic regression. Move to a tiny MLP only if needed.
The personal model must be:
• small,
• incrementally retrainable,
• local-only,
• resettable,
• versioned.
9.5 Cold Start
Before sufficient user labels:
• rely more heavily on deterministic signals,
• do not present personal predictions as highly confident,
• prioritize training examples.
Suggested thresholds (tunable):
• 0–25 labels: no personalized deletion batch,
• 25–100 labels: low-confidence personalization,
• 100+ labels: full personalized ranking allowed.
9.6 People Grouping Quality
• Clustering threshold is tunable and conservative by default, so it prefers splitting one person into two groups over merging two people into one.
• Users can correct clusters, and corrections are stored locally and respected on every rescan.
• Small, blurry, or partial faces below a quality threshold are skipped.
10. Deletion Safety
Hard rules:
1. Never silently delete.
2. Never delete in the background without explicit user approval.
3. Always display the proposed deletion set.
4. Respect platform recycle-bin/trash behavior where available.
5. Show estimated storage to reclaim before confirmation.
6. Record a local audit entry for cleanup actions.
7. Handle partial deletion failures safely.
8. When assets are deleted, remove their embeddings, face data, and cluster entries from local storage.
11. Notifications
Local notifications may be sent for:
• daily/periodic swipe review,
• newly found cleanup batch,
• storage cleanup milestone.
Notifications must not reveal gallery content, people, or names.
12. Technical Architecture
• Framework: Flutter, iOS and Android.
• Photo library access: platform photo library plugin (for example photo_manager).
• On-device inference: tflite_flutter for MobileCLIP and MobileFaceNet, google_mlkit_face_detection for faces.
• Local storage: on-device database (for example SQLite) for features, embeddings, clusters, labels, model weights, and the audit log.
• Local storage is excluded from cloud backup where the platform allows it, so embeddings and face data are not silently synced.
• Backend does not perform gallery inference.
13. Backend Scope
• auth,
• account profile,
• subscription entitlement mirror,
• feature flags,
• app config,
• aggregate product telemetry,
• optional anonymous install tracking,
• rate-limit/account-abuse protection.
14. Success Metrics
Product:
• activation rate,
• first cleanup completion,
• items reviewed per active user,
• storage reclaimed,
• day-7 and day-30 retention,
• free-to-paid conversion,
• people grouping opt-in rate.
AI:
• user agreement rate with recommendations,
• false-positive deletion recommendation rate,
• model confidence calibration,
• percentage of suggestions overridden,
• abstention rate,
• people-cluster correction rate (merges and splits per user).
Performance:
• scan time per 1,000 photos,
• app size increase from models,
• battery impact during scan.
Privacy:
• zero raw media uploaded,
• zero image or face embeddings uploaded,
• zero gallery content sent to third-party APIs,
• zero known gallery-content leakage incidents.
15. V2 Non-Goals
Do not build in V2:
• cloud photo storage,
• cloud gallery or face inference,
• cloud LLM or vision API calls on user media,
• matching faces to real-world identities or external databases,
• LLM chat over the gallery,
• social feed or sharing network,
• photo editor or video editor,
• generative image features,
• cross-device gallery or face-data sync,
• autonomous deletion,
• detailed life-event reconstruction,
• sensitive-trait inference,
• location-map analytics.
16. Open Questions
• Final model sizes after int8 quantization and the resulting app size.
• License terms for the chosen MobileCLIP and MobileFaceNet weights.
• Clustering threshold and algorithm (threshold-based or DBSCAN) after testing on real galleries.
• Whether people grouping is premium-only or has a limited free version.
• Minimum supported device specs for acceptable scan speed.
17. Acceptance Criteria
V2 is complete when:
• Flutter app can browse local photos and videos.
• Scan runs fully on-device, in the background, and is resumable.
• Exact and near-duplicate detection works.
• Screenshots and blurry items can be surfaced.
• Similar photos are grouped with a best-shot suggestion.
• MobileCLIP assigns semantic categories and category filters work.
• People grouping works on-device, and users can rename, merge, split, and disable it with full face-data deletion.
• Swipe Keep/Delete/Skip is implemented and persisted locally.
• Personal model trains and updates locally and ranks suggestions locally.
• Batch cleanup requires explicit review and confirmation.
• Deleting an asset removes its local embeddings and face data.
• Profile shows aggregate charts and storage metrics.
• Subscription entitlement gates premium features.
• Server receives only approved aggregate telemetry.
• Raw media, face data, and embeddings never reach the backend or any third-party API.