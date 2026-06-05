<div align="center">

# CortexKit

**The shared foundation of the Cortex family of native macOS apps.**

The visual identity, the local-AI-via-CLI layer, and the plumbing — extracted
once, so every product reads as one and nobody copy-pastes `Theme.swift` again.

`SwiftUI` · `macOS 26+` · `Swift 6.2` · zero third-party dependencies

</div>

---

## Why

[Cortex DB](../cortex-db), [Cortex Code](../cortex-code) and
[Cortex Agent](../cortex-agent-codebase) grew the same code three times:

- `Theme.swift` was **~83% identical** across the apps, copied verbatim.
- The "AI through your local CLI" layer had **drifted** — `AICLI` +
  `AIService.run()` in one app, `AIBackend` + `AIService.ask()` in another, with
  *different* `PATH`-resolution logic (so one app found `claude` in cases the
  other didn't).
- `Keychain`, `Toast`, `Markdown`, JSON/search highlighters and skeleton loaders
  were duplicated or about to be.

CortexKit makes that shared surface a single versioned Swift package. Edit it
once; every app — including new ones — picks up the change.

## What's inside

CortexKit is **four modules** behind one umbrella, so a consumer takes only what
it needs (a CLI tool can pull `CortexAI` with no SwiftUI link cost):

| Module | Contents |
|---|---|
| **CortexUI** | `Brand` + `BrandConfig` (the injection seam), `AccentTheme` (Violet/Ocean/Sunset/Forest/Graphite), `AuroraBackground`, Liquid Glass (`liquidGlass`, `GlassCard`), `ShimmerText`, `StatusDot`, `LogoMark`, `cascade`, `GradientButtonStyle`/`PressableStyle`, `Animation.cortex` springs |
| **CortexAI** | `AICLI` (claude/codex), `AIProvider` (detect / resolve / run via the user's CLI), `AIText` (strip fences, first-line, truncate) |
| **CortexInfra** | `PrefsStore` (namespaced `UserDefaults`), `Keychain` (service-scoped), `ShellRunner` (PATH resolution + subprocess) — **no UI** |
| **CortexHelpers** | `ToastCenter` + `.toasts()`, `MarkdownText`, `JSONHighlighter`, `SearchHighlight`, `SkeletonRow`/`SkeletonList` |

`import CortexKit` re-exports all four.

## Install

In your app's `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rafaelaugustos/cortex-kit", from: "0.1.0"),
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [
            .product(name: "CortexKit", package: "cortex-kit"),
            // …or pick granular products:
            // .product(name: "CortexUI", package: "cortex-kit"),
        ]
    )
]
```

Requires **macOS 26+** and the **Swift 6.2** toolchain.

## Quick start

Configure once at launch — this installs your app's namespace (for preferences
and the accent theme) and logo into the shared identity:

```swift
import SwiftUI
import CortexKit

@main
struct MyApp: App {
    init() {
        // Returns a PrefsStore you can reuse for your own settings + AIProvider.
        _ = CortexKit.configure(
            namespace: "mynewapp",
            logo: NSImage(named: "AppIcon"),
            fallbackSymbol: "sparkles"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Then build UI with the family's vocabulary:

```swift
struct ContentView: View {
    @StateObject private var toasts = ToastCenter()

    var body: some View {
        ZStack {
            AuroraBackground()                       // the animated brand backdrop
            VStack(spacing: 20) {
                ShimmerText("My New App")
                GlassCard {                          // Liquid Glass + cursor parallax
                    HStack {
                        StatusDot(color: .green)
                        Text("Ready")
                    }
                }
                Button("Do the thing") { toasts.success("Done") }
                    .buttonStyle(.gradient)
            }
            .cascade(delay: 0.05)                    // staggered entrance
        }
        .toasts(toasts)
    }
}
```

### Drive the local AI

No API keys — it shells out to whatever the user already has on `PATH`:

```swift
let prefs = CortexKit.configure(namespace: "mynewapp")   // also returns the store
let ai = AIProvider(prefs: prefs)

if let cli = await ai.resolveBackend() {        // honours a user-pinned backend
    let answer = try await ai.run(prompt: "Summarize this diff…", cli: cli)
    let clean = AIText.firstMeaningfulLine(answer)
}
// Or in one call (auto-detects, throws .noProvider if none installed):
let reply = try await ai.run(prompt: "…")
```

### Store a secret

```swift
let keychain = Keychain(service: "mynewapp.tokens")
keychain.set(token, for: accountID)              // also accepts a UUID
let token = keychain.get(accountID)
```

## Design notes

- **`Brand` is configured, not hard-coded.** The original `Theme.swift` read the
  theme from a `cortexdb.*` `UserDefaults` key and loaded the logo from its own
  `Bundle.module` — both coupled shared code to one app. `BrandConfig` is the
  injection seam: each app provides its namespace + logo via `Brand.configure`
  (or the `CortexKit.configure` shortcut). Until configured, `Brand` falls back
  to a sensible default (Violet, SF Symbol logo) so previews and tests just work.
- **One AI implementation.** `AIProvider` adopts Cortex DB's robust PATH
  resolution (interactive login shell **plus** a scan of common install dirs)
  and Cortex Code's preference-aware backend selection — the strict superset of
  both apps' behaviour.
- **Performance is built in.** `AuroraBackground` throttles from 60→10fps when
  the app loses focus (same look, far less idle CPU/GPU). `NoiseOverlay` uses a
  seeded PRNG so the speckle is computed deterministically, not re-randomised per
  frame. `JSONHighlighter` is a single hand-rolled pass that tolerates partial
  JSON. `ShellRunner` drains stderr concurrently so a full pipe can't deadlock.
- **Granular link cost.** Need only the AI layer? `import CortexAI` and you don't
  link SwiftUI. `CortexInfra` has no dependencies at all.

## Module graph

```
CortexKit  (umbrella, @_exported)
 ├─ CortexUI ───────┐
 │   └─ CortexInfra │
 ├─ CortexAI        │
 │   └─ CortexInfra │
 ├─ CortexInfra ◄───┘   (no dependencies)
 └─ CortexHelpers
     └─ CortexUI
```

## Develop

```sh
swift build
swift test
```

16 unit tests cover the pure logic (`AIText`, `AICLI` argv, `PrefsStore`
namespacing/round-trips). The UI and process layers are exercised by the
consuming apps.

See [API.md](API.md) for the full public surface.

## License

TBD.
