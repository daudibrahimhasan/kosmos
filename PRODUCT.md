# Mikro
<!-- impeccable:product-schema 1 -->

## Platform
adaptive

## Stack
Flutter / Dart, as required by the supplied V2 PRD. SQLite owns native local state.

## Users
Smartphone owners with cluttered galleries who want to reclaim space through short, safe reviews.

## Product Purpose
Browse, review and clean local media without sending gallery content to a server.

## Capabilities and Constraints
The supplied docs/PRD.md is the V2 authority over older V1 documents. Media, thumbnails, embeddings, people labels and decisions remain on-device. Deletion requires visible review, explicit approval and platform confirmation. TinyCLIP category/similarity inference and opt-in YuNet/SFace people grouping are implemented with bundled ONNX models. Browser inference is smoke-tested; native phone performance and accuracy are still unverified. Store-backed subscriptions require provider configuration.

## Brand Commitments
The user confirmed the existing mockup style, then supplied a black gallery reference. Default appearance: black, white and rust, pixel headings, mono labels and square/circle vault tiles. The cream mockup is the light theme. Familiar mobile navigation and confirmation controls remain. Mikro is inferred from the folder name.

## Evidence on Hand
V2 PRD, V1 engineering contracts and a standalone gallery mockup. No application source, model weights, signing identities or store credentials were supplied.

## Product Principles
- User review is final.
- Analysis is local and resumable.
- Unavailable model capabilities must be visible, never simulated as real inference.
- Demonstration content is clearly separated from the device library.

