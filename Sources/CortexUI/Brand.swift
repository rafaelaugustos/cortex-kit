import SwiftUI
import AppKit
import CortexInfra

// MARK: - Accent themes

/// Accent themes: each supplies the 5-color palette that drives the Aurora
/// blobs, status colors and syntax, plus a primary accent. The selected theme
/// is persisted via ``BrandConfig`` (under each app's own namespace).
public enum AccentTheme: String, CaseIterable, Identifiable, Sendable {
    case violet, ocean, sunset, forest, mono

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .violet: return "Violet"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .mono: return "Graphite"
        }
    }

    public var palette: [Color] {
        switch self {
        case .violet:
            return [Color(red: 0.42, green: 0.31, blue: 0.95), Color(red: 0.20, green: 0.65, blue: 0.95),
                    Color(red: 0.95, green: 0.35, blue: 0.65), Color(red: 0.34, green: 0.86, blue: 0.78),
                    Color(red: 0.99, green: 0.55, blue: 0.36)]
        case .ocean:
            return [Color(red: 0.20, green: 0.55, blue: 0.95), Color(red: 0.18, green: 0.78, blue: 0.92),
                    Color(red: 0.34, green: 0.86, blue: 0.78), Color(red: 0.45, green: 0.62, blue: 1.0),
                    Color(red: 0.30, green: 0.90, blue: 0.66)]
        case .sunset:
            return [Color(red: 0.98, green: 0.45, blue: 0.35), Color(red: 0.95, green: 0.35, blue: 0.62),
                    Color(red: 0.99, green: 0.70, blue: 0.30), Color(red: 0.85, green: 0.30, blue: 0.55),
                    Color(red: 0.99, green: 0.55, blue: 0.36)]
        case .forest:
            return [Color(red: 0.30, green: 0.78, blue: 0.55), Color(red: 0.55, green: 0.82, blue: 0.35),
                    Color(red: 0.20, green: 0.65, blue: 0.60), Color(red: 0.34, green: 0.86, blue: 0.62),
                    Color(red: 0.75, green: 0.85, blue: 0.30)]
        case .mono:
            return [Color(red: 0.55, green: 0.55, blue: 0.62), Color(red: 0.45, green: 0.48, blue: 0.58),
                    Color(red: 0.65, green: 0.62, blue: 0.78), Color(red: 0.38, green: 0.40, blue: 0.48),
                    Color(red: 0.72, green: 0.70, blue: 0.82)]
        }
    }

    public var accent: Color {
        switch self {
        case .violet: return Color(red: 0.55, green: 0.42, blue: 1.0)
        case .ocean: return Color(red: 0.26, green: 0.66, blue: 0.98)
        case .sunset: return Color(red: 0.98, green: 0.48, blue: 0.42)
        case .forest: return Color(red: 0.30, green: 0.80, blue: 0.55)
        case .mono: return Color(red: 0.68, green: 0.66, blue: 0.80)
        }
    }
}

// MARK: - Brand configuration (the injection seam)

/// Per-app configuration for the shared visual identity.
///
/// The original `Theme.swift` read the accent theme straight from
/// `UserDefaults` with a hard-coded `cortexdb.*` key, and loaded the logo from
/// the app's own `Bundle.module` — both of which couple shared code to one
/// product. `BrandConfig` is the injection seam that removes that coupling:
/// each app builds one at launch and installs it via ``Brand/configure(_:)``.
///
/// ```swift
/// Brand.configure(
///     BrandConfig(
///         prefs: PrefsStore(namespace: "cortexcode"),
///         logo: NSImage(named: "AppIcon"),
///         fallbackSymbol: "chevron.left.forwardslash.chevron.right"
///     )
/// )
/// ```
public struct BrandConfig: @unchecked Sendable {
    /// Namespaced store the accent theme is read from / written to.
    public let prefs: PrefsStore
    /// Preference suffix holding the selected ``AccentTheme`` raw value.
    public let themeKey: String
    /// The app's logo image (per-app, so the package never bundles one).
    public let logo: NSImage?
    /// SF Symbol drawn when `logo` is `nil`.
    public let fallbackSymbol: String
    /// Theme used when none is stored yet.
    public let defaultTheme: AccentTheme

    public init(
        prefs: PrefsStore,
        themeKey: String = "accentTheme",
        logo: NSImage? = nil,
        fallbackSymbol: String = "circle.hexagongrid.fill",
        defaultTheme: AccentTheme = .violet
    ) {
        self.prefs = prefs
        self.themeKey = themeKey
        self.logo = logo
        self.fallbackSymbol = fallbackSymbol
        self.defaultTheme = defaultTheme
    }
}

// MARK: - Brand

/// The shared brand surface: palette, accent and gradients, all derived from
/// the currently selected ``AccentTheme``.
///
/// Call ``configure(_:)`` once at launch. Until then, ``Brand`` falls back to a
/// default in-memory config (Violet, no logo) so previews and tests work with
/// no setup.
public enum Brand {
    nonisolated(unsafe) private static var config = BrandConfig(
        prefs: PrefsStore(namespace: "cortexkit")
    )

    /// Installs the per-app configuration. Call once, early (e.g. `App.init`).
    public static func configure(_ config: BrandConfig) {
        self.config = config
    }

    /// The currently selected theme, read from the configured store.
    public static var theme: AccentTheme {
        let raw = config.prefs.string(for: config.themeKey) ?? ""
        return AccentTheme(rawValue: raw) ?? config.defaultTheme
    }

    /// Persists the selected theme.
    public static func setTheme(_ theme: AccentTheme) {
        config.prefs.set(theme.rawValue, for: config.themeKey)
    }

    public static var palette: [Color] { theme.palette }
    public static var accent: Color { theme.accent }

    public static var gradient: LinearGradient {
        LinearGradient(colors: [palette[0], palette[1], palette[2]],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The app's logo, or `nil` if none was configured.
    public static var logo: NSImage? { config.logo }
    /// SF Symbol fallback name for ``LogoMark``.
    public static var fallbackSymbol: String { config.fallbackSymbol }
}

// MARK: - Brand mark

/// The app's logo with a soft brand glow, falling back to an SF Symbol when no
/// logo was configured.
public struct LogoMark: View {
    public var size: CGFloat

    public init(size: CGFloat = 40) { self.size = size }

    public var body: some View {
        Group {
            if let img = Brand.logo {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: Brand.fallbackSymbol)
                    .resizable().scaledToFit()
                    .foregroundStyle(Brand.gradient)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Brand.accent.opacity(0.5), radius: size / 4)
    }
}
