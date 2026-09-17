# ChaosLab — Flutter Client

MVVM Flutter client for the ChaosLab backend: paste a public GitHub repo,
confirm the parsed architecture, configure a load + failure scenario, watch
the agent pipeline run live, and read the findings.

## Setup

This directory ships only Dart source + `pubspec.yaml` — platform folders
(`android/`, `ios/`, `web/`, etc.) aren't included, since they're
machine-generated and this keeps the zip small. Regenerate them once:

```bash
cd frontend/chaoslab_flutter
flutter create . --platforms=android,ios,web   # or whichever you need
flutter pub get
```

Edit `.env` (a working default is already included, pointing at
`http://127.0.0.1:8000`) if your backend runs somewhere else:

- Android emulator → host machine backend: `http://10.0.2.2:8000`
- iOS simulator / desktop / web: `http://127.0.0.1:8000`
- Physical device: `http://<your-computer-lan-ip>:8000`

Then run:

```bash
flutter run
```

## Architecture (MVVM)

```
lib/
  main.dart, app.dart          entrypoint + MaterialApp
  core/
    theme/                     dark "mission control" visual language
    network/dio_client.dart    shared Dio instance + typed ApiException
    network/sse_client.dart    hand-rolled SSE parser over Dio's byte stream
    di/service_locator.dart    wires datasources -> repositories once at startup
    constants/api_constants.dart
  data/
    models/                    plain Dart classes mirroring backend schemas.py
                                field-for-field, with fromJson/toJson
    datasources/                Dio calls, one per backend router
    repositories/               implements the domain interfaces
  domain/
    repositories/               abstract contracts — ViewModels depend on
                                these, never on Dio or a concrete data source
  viewmodels/                   ChangeNotifier per screen; all business logic
                                and API orchestration lives here, not in widgets
  presentation/
    repo_input/                 screen 1: paste a GitHub URL
    architecture_preview/       screen 2: confirm/edit parsed services
    simulation_config/          screen 3: target load + failure scenario
    simulation_live/            screen 4: live agent-activity feed (SSE)
    report/                     screen 5: bottlenecks, metrics, remediation plan
    shared/widgets/              MetricBar, SectionHeader, ErrorBanner
```

Each screen widget builds its own `ChangeNotifierProvider` around its
ViewModel and reads it via `context.watch`. There's no global app state and
no routing package — navigation is plain `Navigator.push`/
`pushReplacement`/`pushAndRemoveUntil`, which is all a 5-screen linear flow
actually needs. If this grows past that, `go_router` would be the natural
next dependency, but adding it now would be indirection without payoff.

## Why plain `ChangeNotifier` + `provider`, not Bloc/Riverpod

The MVVM boundary is the thing being demonstrated here (Views never call a
repository directly, ViewModels never import Dio), and `ChangeNotifier` +
`provider` makes that boundary the most explicit and least "magic" to
someone reading the code for the first time — worth optimizing for in a
portfolio piece, even though Bloc or Riverpod would be reasonable choices
too in a larger app.

## The live agent feed

`SimulationLiveViewModel` subscribes to
`/api/v1/simulation/stream/{id}` and appends one `AgentStepEvent` to a list
per SSE `agent_step` event, so `AgentActivityRow` widgets light up one at a
time as each backend agent hands off to the next — this is the screen worth
recording a short screen capture of for a LinkedIn post. If the SSE
connection drops before the terminal `final_report` event arrives, the
ViewModel automatically falls back to a single poll of the report endpoint
so the screen never gets stuck on a spinner.
