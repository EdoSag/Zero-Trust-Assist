# Zero-Trust Assist

A private AI assistant for the [Zero-Trust apps](https://zerotrust.bz) that
runs on the phone itself. On the phone it is called **ZT Assist**; in stores
and on release pages, **Zero-Trust Assist**. The model is an open one (Gemma
4, Apache 2.0) and answers on the device: nothing you type is sent anywhere,
and it works with no connection at all. The only network use is downloading
the model file once.

ZT Assist will be two things: a chat app of its own, and the engine the other
Zero-Trust apps call for things like summarizing a note, rewriting a selection
or turning "dentist tomorrow at 9" into an event.

## Where it is now: the phone test

This first version is a test bench, not the assistant yet. It answers one
question before anything is built on top: how well do these models run on a
real phone, and how good is their Hebrew?

It can:

- download the candidate models (each pinned by size and SHA-256, resumable);
- run a fixed set of 42 requests in Hebrew, English and mixed text (two long
  ones for speed, forty short ones covering summarize, rewrite, proofread,
  translate, quick add, titles, lists and questions);
- measure load time, reading and writing speed, the wait before an answer
  starts, memory, heat and battery;
- check the quick add answers (date and time) automatically;
- save every run as a JSON file and share it;
- chat with a model, to judge answers by hand.

| Model | Engine | Size | Why it is in the test |
|---|---|---|---|
| Gemma 4 E2B | LiteRT-LM | 2.6 GB | The planned default |
| Gemma 4 E4B | LiteRT-LM | 3.7 GB | Larger option for phones with 12 GB or more |
| DictaLM 3.0 1.7B | llama.cpp | 1.1 GB | Hebrew-tuned backup |
| Gemma 4 E2B (GGUF) | llama.cpp | 3.1 GB | Same model on the other engine, to compare engines |

### Running the test

1. Install the APK (from the pull request's build, or from Releases).
2. Download Gemma 4 E2B on Wi-Fi.
3. Unplug the phone, tap **Run test**, pick **Quick** and **CPU**, and keep the
   app open until it finishes.
4. Tap **Share results file** and send the file.

The full test, the other models and the GPU run follow the same steps. On
GrapheneOS the GPU run is expected to fail; that is recorded as a result.

Keep the test on screen while it runs. Android moves an app that is off
screen to the slow processor cores, and the model then writes at about a
third of its speed. Answers written that way are marked in the results file
and left out of the speeds.

## Privacy

- The model answers on the device. Nothing you type is sent anywhere, and it
  works with no connection at all.
- The only network use is downloading a model file, each pinned by size and
  SHA-256.
- The test app has no account and no sign-in. A results file leaves the phone
  only when you share it.

## Install

Android 11 or newer, 64-bit ARM. There is no release yet: the test APK comes
from the pull request's build. Once the app is released, signed APKs will be on
this repository's [Releases](https://github.com/EdoSag/Zero-Trust-Assist/releases)
page, like the other Zero-Trust apps. The test app is in English.

## How it is built

- `lib/engine/` is the only place that touches a model runtime. The rest of
  the app talks to `AssistEngine`, so the library underneath can be replaced.
  Today it is [llamadart](https://pub.dev/packages/llamadart) (MIT), which
  wraps llama.cpp and LiteRT-LM and fetches their prebuilt native libraries at
  build time. Its version is pinned exactly.
- `lib/lab/` is the test: the model list, the requests, the runner and the
  result files.
- `lib/ui/` is the three screens.
- `android/.../MainActivity.kt` reads memory, heat and battery for the test.

## Build from source

Flutter 3.47.9, the version CI pins.

```
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request; a push to `main`
builds a signed APK and publishes it as a GitHub Release named "Zero-Trust
Assist" (`.github/workflows/android-apk.yml`), signed with the keystore shared
by all Zero-Trust apps.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences. Model files are downloaded
separately and keep their own licenses (Apache 2.0 for the ones listed above).

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
