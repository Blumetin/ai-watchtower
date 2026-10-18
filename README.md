# AI Watchtower — Taiwan Disaster Alerts

Turning Taiwan's official hazard alerts into plain-language, multilingual guidance.
Built with Gemini on Cloud Run and Firebase — official severity first, AI only fills gaps.

Entry for the Google Cloud AI Builder Cup 2026 (theme: Sustainability & Social Impact) by team **Watchtower Lab**.
The app ships as **Taiwan Disaster Alerts** (防災速報) on Android and the web; AI Watchtower is the project name.
Push alerts are live on Android. The iOS app is in TestFlight testing and not yet available to the public.

**Try the web app:** https://ai-watchtower-tw.web.app (no account needed)

## Trying it (for judges)

Open https://ai-watchtower-tw.web.app in any browser. No account is needed.

Questions you can ask in the Q&A tab:
- "Are there any alerts currently in effect for Taipei?" (answered via function calling over current alert data)
- "What should I do if I am indoors during an earthquake?"
- 「颱風來之前家裡要準備什麼？」 (What should I prepare at home before a typhoon?)
- 「避難バッグには何を入れればいいですか？」 (What should go in a go-bag?)

Good to know:
- Q&A has usage limits, so you may occasionally be asked to try again later.
- The service checks alerts every 10 minutes and earthquake reports every 2 minutes. The alert list may be empty when no alerts are in effect.
- The Android app is heading to closed testing on Google Play, and the iOS app is being tested through TestFlight. Neither is publicly available, so please use the web app.
- AI-generated summaries and translations may contain errors. Always follow the issuing agency's original notice, available with one tap.

## What it does

Taiwan's official hazard alerts arrive as long technical notices, mostly in Chinese.
This app makes them readable for residents, migrant workers and visitors who cannot read Chinese.

- **Current alerts** — polls Taiwan's national disaster feed (NCDR CAP alerts) every 10 minutes and Central Weather Administration earthquake reports every 2 minutes.
- **Plain-language summaries** — Gemini summarizes only the longer alerts; short ones are shown as published. New alerts get English and Japanese translations; code checks the numbers against the original (and county names for Japanese). A translation that fails a check is replaced by the Chinese original.
- **Official severity first** — the agency's CAP severity always wins. Only when an alert carries no official level does the model assign one, and it can assign at most *Critical* (orange), never *Extreme* (red). AI-assigned levels affect display only; push notifications follow the official level.
- **Ask in everyday words** — Code routes each question first: current alerts through function calling, preparedness questions through retrieval over official guidance; answers grounded in official data show their sources. Crisis questions always open with fixed helpline text; earthquake-prediction questions get a fixed, non-AI answer.
- **Push notifications** (Android) for Extreme alerts, and Critical alerts when the agency itself rated them Severe.
- No account, no location tracking.

## Architecture

| Layer | Technology |
|---|---|
| App | Flutter — one codebase for Android, iOS and web |
| Backend | Cloud Functions for Firebase (2nd gen, Python 3.13, on Cloud Run): `poll_alerts`, `poll_quakes`, `enrich_alert`, `ask`, `report_answer` |
| Scheduling | Cloud Scheduler (10 min / 2 min), Eventarc on Firestore create |
| Data | Cloud Firestore (alerts, history, earthquakes, reports) |
| AI | Gemini API — `gemini-3.1-flash-lite` (summaries, grading fallback, translation, Q&A routing), `gemini-embedding-2` (retrieval) |
| Security | Firebase App Check (Play Integrity / App Attest / reCAPTCHA Enterprise), enforced on callables and Firestore; per-source rate limiting |
| Delivery | Firebase Cloud Messaging (county topics), Firebase Hosting |

## Data sources

- Alerts: National Science and Technology Center for Disaster Reduction (NCDR) alert feed.
- Earthquake reports: Central Weather Administration (CWA) open data, under Taiwan's Open Government Data License v1.0 (https://data.gov.tw/license).
- County boundaries bundled in `assets/data/` (`tw_counties.meta.json`): National Land Surveying and Mapping Center, Ministry of the Interior, version 1140318, Open Government Data License v1.0.
- Historical earthquake catalogue bundled in `assets/data/`: USGS Earthquake Catalog (U.S. Government work, public domain).
- Preparedness content in `assets/content/*.json` cites its official source in the `source` field.

## Repository layout

```
lib/                 Flutter app (screens, data layer, widgets, l10n)
assets/              bundled content, county boundaries, fonts (OFL)
android/ ios/ web/   platform projects
functions/           Cloud Functions (Python) — functions/watchtower/ is the package
src/                 data pipeline tools and tests
tool/ tools/         build and content-prep helpers
firestore.rules      Firestore security rules (read-only for clients)
```

## Running it yourself

This repository is a snapshot of the code behind the submission. To run it you need your own Google Cloud / Firebase project:

1. Create a Firebase project and run `flutterfire configure` to generate `lib/firebase_options.dart`, `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`. These files are git-ignored; `lib/firebase_options.dart.example` shows the expected shape.
2. Put your Gemini API key and CWA API key in Secret Manager (production) or in your shell (local), see `src/env.example` and `functions/.env.example`.
3. Enable App Check for your app IDs, or run with the debug provider on emulators.
4. `cd functions && pip install -r requirements.txt && firebase deploy --only functions`
5. `flutter run` (Android / web) or build with `tool/build_web.sh` and `tool/build_android_release.sh`.
6. iOS: open `ios/Runner.xcworkspace` in Xcode and select your own development team under Signing & Capabilities (the team ID is intentionally blank in this repository).

## What is not in this repository

- The crisis-detection word lists in `functions/watchtower/qa.py` (`DISTRESS_ZH`, `INTENS_ZH`, `TAIL_ZH`) are intentionally empty here. The production lists live in a private config so they cannot be gamed.
- The preparedness knowledge base (chunks and embeddings) is not included because parts of the source material carry licence restrictions. `src/kb/build_chunks.py` shows how it is built.
- Firebase configuration files, API keys, data snapshots and logs.
- Tests in `src/` are included for reference. Most depend on the private knowledge base, fixture data or live services (Gemini API, CWA API, the deployed functions) and will not run as-is; `test_rocdate.py`, `test_severity.py` and `test_status.py` run offline.
- Code comments are removed from this public snapshot.

## License

Apache License 2.0 — see `LICENSE`. Copyright 2026 Watchtower Lab.

## Names and trademarks

Google, Gemini, Firebase, Flutter, Google Cloud and Google Maps are trademarks of Google LLC. This is an independent project, not a government app; always follow the original notice from the issuing agency.
