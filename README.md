# Zero-Trust Assist

A private AI assistant for the Zero-Trust apps that runs on the phone itself.
The model is an open one (Gemma 4, Apache 2.0) and answers on the device:
nothing you type is sent anywhere, and it works with no connection at all. The
only network use is downloading the model file once.

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

## Code

- `lib/engine/` is the only place that touches a model runtime. The rest of
  the app talks to `AssistEngine`, so the library underneath can be replaced.
  Today it is [llamadart](https://pub.dev/packages/llamadart) (MIT), which
  wraps llama.cpp and LiteRT-LM and fetches their prebuilt native libraries at
  build time. Its version is pinned exactly.
- `lib/lab/` is the test: the model list, the requests, the runner and the
  result files.
- `lib/ui/` is the three screens.
- `android/.../MainActivity.kt` reads memory, heat and battery for the test.

```
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

Android 11 or newer, 64-bit ARM. Flutter 3.47.9 is what CI uses.

## License

AGPL-3.0. See [LICENSE](LICENSE). Model files are downloaded separately and
keep their own licenses (Apache 2.0 for the ones listed above).
