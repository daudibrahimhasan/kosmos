# Selected on-device ML stack

Updated November 4, 2026. The models now run through ONNX Runtime on-device.

## Runtime pipeline

| Job | Model and input | Saved local result |
| --- | --- | --- |
| Categories, similarity and personal ranking inputs | TinyCLIP ViT-8M/16 image encoder, 224 px center crop, RGB ImageNet/CLIP normalization | Normalized 512-value embedding and cosine score for each configured prompt category |
| People grouping, opt-in | YuNet with five landmarks at 320 × 320, then landmark-aligned SFace at 112 × 112 | Normalized 128-value face vector and normalized face rectangle |
| Personal ranking | Local logistic regression over existing deterministic features plus the 512 TinyCLIP values | Suggestions begin only after 100 explicit labels; they never authorize deletion |

The category text tower is not shipped in the app. `tool/prepare_models.py` encodes the prompts in `assets/models/category_prompts.json` with the pinned TinyCLIP checkpoint and writes the normalized prototypes to `categories.json`. Changing prompts needs that local preparation step. Weak or nearly tied matches become `Other`. Similar-photo candidates use embedding sign bands, then cosine similarity; they remain suggestions for review.

People grouping starts off. YuNet and SFace are not loaded until it is enabled. Turning it off clears face vectors, names and corrections from saved state, waits for an active scan, closes the face sessions, and compacts the native SQLite database. Deleting a photo also removes its face records. No identity labels are inferred and no photo, vector or analytics request is sent to a server.

## Models and licenses

- TinyCLIP source: [author model card](https://huggingface.co/wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M/tree/a2a8c6eaa2549ad66eb7c31b85022bf58273a26c), revision `a2a8c6eaa2549ad66eb7c31b85022bf58273a26c`, MIT model-card license. The bundled image encoder is an ONNX export; text prototypes are generated locally from the prompt file.
- YuNet source: [OpenCV Zoo pinned commit](https://github.com/opencv/opencv_zoo/tree/48b10fa505aeb51fbd127fc60a5c660040e823b7/models/face_detection_yunet), MIT. The bundled graph was adapted to 320 × 320 input and its derived shapes were revalidated.
- SFace source: [OpenCV Zoo pinned commit](https://github.com/opencv/opencv_zoo/tree/48b10fa505aeb51fbd127fc60a5c660040e823b7/models/face_recognition_sface), Apache 2.0.
- Runtime: `flutter_onnxruntime` 1.9.0. Web bundles `onnxruntime-web` 1.31.1 and its MIT license/third-party notices. iOS target is 16.0 to match the plugin's minimum.

License files ship beside the model assets; web runtime notices are in `web/ort`.

## Validation and limits

`tool/prepare_models.py` compares the exported TinyCLIP image encoder with the pinned PyTorch model on the 12 bundled images. `docs/model-validation.json` stores per-image cosine agreement and category scores. In a Chrome browser scan, 30 sample entries produced 512-value embeddings; the 12 unique photo images matched 11 configured top categories, with the ambiguous portrait abstaining to `Other`. With People enabled, YuNet/SFace produced four face records across repeated sample portraits, grouped as two repeated people. Turning People off was checked to remove all face records and groups from browser IndexedDB.

This is a smoke test on bundled stock photos. It is not an accuracy benchmark. The clustering threshold, crop/preprocessing agreement across all devices, false-match rate, latency, battery, memory and thermals need broader validation. Browser inference is verified; Android and iOS builds still need their native toolchains and physical-device runs. No quantization is used.

See `assets/models/manifest.json` for file sizes and SHA-256 hashes. Re-exporting the image graph or changing the image encoder requires changing `AiEngine.version` so cached vectors are regenerated.
