# Verification record

November 4, 2026. Windows, Flutter 3.47.9, Dart 3.13.7, Chrome 156.

- `flutter analyze`: passed, no issues.
- `flutter test`: 18 passed. Two new gesture checks also passed after the final motion refinement.
- `flutter build web --release --no-web-resources-cdn`: passed.
- Browser flow: sample scan populated duplicate candidates; Cancel retained the reviewed selection; explicit confirmation removed one sample; review Delete queued a different item; reload preserved the confirmed deletion, review decision and light theme.
- Browser capture run: no page errors and no requests to external hosts.
- Preview viewports: 390 × 844, 768 × 1024, 1440 × 1000. Captures include Gallery, Albums, Cleaner, batch review, confirmation, swipe review, Insights, Settings and light mode.
- Widget tests additionally cover phone text scaling at 1.5×.
- Independent visual review: ship at browser-preview scope; all 11 captures reviewed, no material findings. Native acceptance remains unverified.
- Native toolchains unavailable: no Android SDK; iOS requires macOS/Xcode. No native build, native screenshots, signed app or device deletion test has been completed.

The browser library is synthetic. These checks do not establish V2 acceptance, real-gallery AI accuracy, native media permission/deletion behavior, background operation, battery impact, or native performance. See README.md for the remaining V2 work.

## Review swipe update

Review now uses a finger-tracking, tilted, three-card deck. Tests cover short-drag cancellation, slow committed swipes, single decision persistence, failure recovery and reduced motion. Button decisions use the same exit path as gestures. Left swipes still only queue items; no deletion behavior changed. Browser motion checks and captures are recorded separately under `.impeccable/review/swipe-*`. The earlier independent visual verdict applies to the original preview, not this later motion change.
`swipe-check` browser run: phone and desktop short drags returned without a decision; right/left swipes each persisted once; queue contained one item and sample tombstones remained empty. Light-mode capture checked. No browser page errors. Final release web build and analyzer passed.

## Local AI integration

November 4, 2026. Flutter 3.47.9, Dart 3.13.7, Chrome 156.

- TinyCLIP ViT-8M/16 was exported to ONNX. The 12 bundled photos' exported image vectors match the pinned PyTorch model in `docs/model-validation.json` (cosine agreement rounds to 1.0).
- A browser scan analyzed 30 sample entries with real photo-pixel inference and saved 512-value embeddings and category scores. Eleven of the 12 unique bundled photos matched their expected top category; the ambiguous `woman.jpg` abstained to Other.
- Browser loaded the bundled TinyCLIP, YuNet and SFace ONNX files from the local app origin. No external request was needed for inference.
- With People enabled, YuNet/SFace detected four face instances in the repeated sample portraits and grouped them into two repeated people. Turning it off removed all face vectors, group assignments and names from the browser IndexedDB state.
- Added unit coverage for semantic grouping, local corrections, restart/erasure, personalized-feature vectors, face alignment, YuNet decoding and NMS.
- Native Android/iOS inference has not been built or run here. iOS deployment target is set to 16.0 for the selected plugin. Physical-device accuracy, speed, memory, battery and thermal checks remain open.

This browser smoke test uses a dozen bundled stock photos, not personal galleries. It does not establish face-clustering accuracy or production performance. The earlier visual review applies to the interface preview, not model quality.
