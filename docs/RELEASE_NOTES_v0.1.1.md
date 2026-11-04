# Mikro v0.1.1 Android preview

Moves TinyCLIP image decoding and preprocessing off the UI isolate. Limits ONNX model sessions to one thread and disables retained CPU arenas to reduce memory pressure. Model status now shows actual embedding counts, scan progress and errors, with a scan action.

This addresses plausible causes of the reported freeze/close during scanning. The device crash has not been reproduced or confirmed resolved on a physical phone.

Preview/debug signed APK, Android API 24+, arm64 Flutter target. People grouping remains opt-in.
