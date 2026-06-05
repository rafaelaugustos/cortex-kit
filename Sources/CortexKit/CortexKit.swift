// CortexKit — a native macOS UI + foundation kit, built entirely in Swift.
//
// An "Aurora + Liquid Glass" design system, a zero-API-key AI layer that drives
// the user's local CLI, and the usual plumbing (preferences, Keychain, shell).
//
// This umbrella module re-exports the four library targets, so a consumer can
// write a single `import CortexKit` and reach everything:
//
//   import CortexKit
//
//   @main struct MyApp: App {
//       init() {
//           CortexKit.configure(namespace: "mynewapp", logo: NSImage(named: "AppIcon"))
//       }
//       var body: some Scene { /* … */ }
//   }
//
// Prefer importing a single sub-module (`import CortexUI`, `import CortexAI`, …)
// when you only need one slice and want to keep link cost minimal.

@_exported import CortexUI
@_exported import CortexAI
@_exported import CortexInfra
@_exported import CortexHelpers

import AppKit

public enum CortexKit {
    /// The package version, kept in sync with the git tag.
    public static let version = "0.1.0"

    /// One-call setup for an app adopting the kit's identity. Builds a
    /// ``PrefsStore`` for `namespace`, installs the ``BrandConfig`` so the
    /// shared UI reads/writes the accent theme under that namespace, and wires
    /// the app logo. Returns the store so the app can reuse it for its own
    /// preferences and for ``AIProvider``.
    ///
    /// - Parameters:
    ///   - namespace: the app's preference key prefix, e.g. `"cortexcode"`.
    ///   - logo: the app's logo image (per-app; the package bundles none).
    ///   - fallbackSymbol: SF Symbol drawn when `logo` is `nil`.
    ///   - defaultTheme: theme used until the user picks one.
    @discardableResult
    public static func configure(
        namespace: String,
        logo: NSImage? = nil,
        fallbackSymbol: String = "circle.hexagongrid.fill",
        defaultTheme: AccentTheme = .violet
    ) -> PrefsStore {
        let prefs = PrefsStore(namespace: namespace)
        Brand.configure(
            BrandConfig(
                prefs: prefs,
                logo: logo,
                fallbackSymbol: fallbackSymbol,
                defaultTheme: defaultTheme
            )
        )
        return prefs
    }
}
