# Zero-Trust Assist

A private AI assistant for the [Zero-Trust apps](https://zerotrust.bz) that
runs on the phone itself. On the phone it is called **ZT Assist**; in stores
and on release pages, **Zero-Trust Assist**. The model is an open one (Gemma
4, Apache 2.0) and answers on the device: nothing you type is sent to any AI
service, and answering works with no connection at all. Chats are saved the
way notes are in the other apps, encrypted on the phone before they sync.

ZT Assist will be two things: a chat app of its own, and the engine the other
Zero-Trust apps call for things like summarizing a note, rewriting a selection
or turning "dentist tomorrow at 9" into an event.

## Where it is now

The chat app is in place: sign in with your Zero-Trust account, pick the small
or the large model, and chat. The link to the other apps is in place too:
ZT Assist can answer them. ZT Notes is the first to use it ("Ask ZT Assist"
in a note), and quick add in ZT Tasks and ZT Calendar can read a typed line
through it.

- **Model choice.** On first launch the app offers the small model (Gemma 4
  E2B, 2.6 GB) and the large one (Gemma 4 E4B, 3.7 GB) and marks the one that
  suits the phone's memory: the large model for 12 GB or more. Switch, download
  the other or delete one under Settings, Model.
- **Chat.** Answers appear as they are written and can be stopped. Bold text,
  lists and code in an answer are shown as such, each line in its own reading
  direction, so Hebrew and English mix correctly.
- **History.** Chats are encrypted on the phone and synced to your other
  devices like notes are. The server stores only sealed data.
- **Hebrew and English**, from Settings, Appearance, Language.
- **Answering the other apps.** Another Zero-Trust app on the same phone can
  hand ZT Assist a text and ask for a summary, a rewrite, a correction, a
  translation, a title, an answer to its own question, or to have a typed
  line like "dentist tomorrow at 9" read into a title, a day and a time. The text goes from
  one app to the other on the phone and nowhere else. Only apps signed with
  the same key as ZT Assist are answered, which is every Zero-Trust app and
  nothing else. The model the user picked answers; it is loaded when asked
  and freed about two minutes after the last answer.

### The phone test

Under Settings, Phone test, is the test bench this app started as. It answers
how well the models run on a real phone, and how good their Hebrew is. It is
in English.

It can:

- download the candidate models (each pinned by size and SHA-256, resumable);
- run a fixed set of 42 requests in Hebrew, English and mixed text (two long
  ones for speed, forty short ones covering summarize, rewrite, proofread,
  translate, quick add, titles, lists and questions);
- measure load time, reading and writing speed, the wait before an answer
  starts, memory, heat and battery;
- check the quick add answers (date and time) automatically;
- save every run as a JSON file and share it;
- chat with a model, to judge answers by hand;
- check the link for other apps: **Link for other apps** asks ZT Assist the
  way the other apps will, and shows the answer and how fast it was written;
- check search by meaning, the next step: **Search test** on the search
  model reads 24 sample notes in Hebrew and English, makes 24 searches worded
  differently from the notes (some in the other language), and reports how
  often the right note came out on top, how long a note takes to read and
  how long a search takes.

| Model | Engine | Size | Why it is in the test |
|---|---|---|---|
| Gemma 4 E2B | LiteRT-LM | 2.6 GB | The planned default |
| Gemma 4 E4B | LiteRT-LM | 3.7 GB | Larger option for phones with 12 GB or more |
| DictaLM 3.0 1.7B | llama.cpp | 1.1 GB | Hebrew-tuned backup |
| Gemma 4 E2B (GGUF) | llama.cpp | 3.1 GB | Same model on the other engine, to compare engines |
| EmbeddingGemma 300M | llama.cpp | 0.3 GB | The planned search model (finds texts by meaning, cannot chat) |

#### Running the test

1. Install the APK (from the pull request's build, or from Releases), sign in
   and open Settings, Phone test.
2. Download Gemma 4 E2B on Wi-Fi (already there if it is your chat model).
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

- The model answers on the device. What you type to it and what it answers is
  never sent to any AI service, and answering works with no connection at all.
- Chats are saved like notes in the other Zero-Trust apps: encrypted on the
  phone with a key only you hold, then synced to your account. Nobody else,
  the server included, can read them.
- The network is used for three things only: signing in, syncing the
  encrypted chats, and downloading a model file (each pinned by size and
  SHA-256) from huggingface.co.
- A phone test's results file leaves the phone only when you share it.
- A text another Zero-Trust app asks about is handed over on the phone, is
  not saved by ZT Assist, and is not added to your chats.

## Install

Android 11 or newer, 64-bit ARM. There is no release yet: the test APK comes
from the pull request's build. Once the app is released, signed APKs will be on
this repository's [Releases](https://github.com/EdoSag/Zero-Trust-Assist/releases)
page, like the other Zero-Trust apps. The app is made for phones with 8 GB of
memory or more.

## How it is built

- `lib/engine/` is the only place that touches a model runtime. The rest of
  the app talks to `AssistEngine`, so the library underneath can be replaced.
  Today it is [llamadart](https://pub.dev/packages/llamadart) (MIT), which
  wraps llama.cpp and LiteRT-LM and fetches their prebuilt native libraries at
  build time. Its version is pinned exactly.
- `lib/chat/` is the chat: conversations (`ZtCollection` items of the
  `assist` app, kind `chat`), the prompt sent to the model, the one model kept
  in memory, and the controller that sends a message and saves the answer.
- `lib/models/` says which models the chat offers and which suits a phone.
- `lib/app/` is the sign-in gate and settings on the shared
  [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).
- `lib/ui/` is the screens: model choice, chat, chat list, settings.
- `lib/lab/` is the phone test: the model list, the requests, the runner, the
  result files and its own screens.
- `lib/service/` answers the other apps. `assist_protocol.dart` is what they
  can ask and the wording the model is given for each job (in Hebrew for
  Hebrew text); `engine_host.dart` answers the requests one at a time;
  `service_main.dart` is where it starts.
- `android/.../AssistService.java` is the Android service the other apps
  connect to. It runs in a process of its own with no screen, starts the
  Dart code in `lib/service/` there, and checks the signature of the sender
  of every message. When the last app lets go, the process ends and the
  model's memory is given back. The other apps reach it through the
  `zt_assist` package of Zero-Trust-Core; the message numbers and field
  names are shared by hand between the two.
- `android/.../MainActivity.kt` reads memory, heat and battery, and keeps the
  screen on during an answer.

## Build from source

Flutter 3.47.9, the version CI pins.

The app reads the Supabase URL and publishable key from a `.env` file (not
committed; CI writes the shared public values):

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

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
