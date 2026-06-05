import Foundation

/// A thin, namespaced wrapper over `UserDefaults`.
///
/// The Cortex apps all store preferences under a per-app key prefix
/// (`cortexdb.*`, `cortexcode.*`, …). Hard-coding that prefix inside shared
/// code would couple the package to one product, so `PrefsStore` takes the
/// namespace at construction time and derives every key from it:
///
/// ```swift
/// let prefs = PrefsStore(namespace: "cortexdb")
/// prefs.set("violet", for: "accentTheme")   // writes "cortexdb.accentTheme"
/// prefs.string(for: "accentTheme")          // reads it back
/// ```
///
/// It is `@unchecked Sendable` and safe to share: the only stored reference is
/// a `UserDefaults`, whose access is documented as thread-safe; everything else
/// the store holds is a value type.
public struct PrefsStore: @unchecked Sendable {
    public let namespace: String
    private let defaults: UserDefaults

    /// - Parameters:
    ///   - namespace: the per-app key prefix, e.g. `"cortexdb"`. A trailing dot
    ///     is added automatically; pass it without one.
    ///   - defaults: the backing store. Defaults to `.standard`; inject a
    ///     suite-scoped instance in tests.
    public init(namespace: String, defaults: UserDefaults = .standard) {
        self.namespace = namespace
        self.defaults = defaults
    }

    /// Fully-qualified key for `suffix`, e.g. `"cortexdb.accentTheme"`.
    public func key(_ suffix: String) -> String { "\(namespace).\(suffix)" }

    // MARK: - Read

    public func string(for suffix: String) -> String? {
        defaults.string(forKey: key(suffix))
    }

    public func string(for suffix: String, default fallback: String) -> String {
        defaults.string(forKey: key(suffix)) ?? fallback
    }

    public func bool(for suffix: String, default fallback: Bool = false) -> Bool {
        defaults.object(forKey: key(suffix)) == nil ? fallback : defaults.bool(forKey: key(suffix))
    }

    public func int(for suffix: String, default fallback: Int = 0) -> Int {
        defaults.object(forKey: key(suffix)) == nil ? fallback : defaults.integer(forKey: key(suffix))
    }

    public func double(for suffix: String, default fallback: Double = 0) -> Double {
        defaults.object(forKey: key(suffix)) == nil ? fallback : defaults.double(forKey: key(suffix))
    }

    // MARK: - Write

    public func set(_ value: String?, for suffix: String) {
        defaults.set(value, forKey: key(suffix))
    }

    public func set(_ value: Bool, for suffix: String) {
        defaults.set(value, forKey: key(suffix))
    }

    public func set(_ value: Int, for suffix: String) {
        defaults.set(value, forKey: key(suffix))
    }

    public func set(_ value: Double, for suffix: String) {
        defaults.set(value, forKey: key(suffix))
    }

    public func remove(_ suffix: String) {
        defaults.removeObject(forKey: key(suffix))
    }
}
