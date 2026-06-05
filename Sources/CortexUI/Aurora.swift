import SwiftUI
import AppKit

// MARK: - Animation tokens

public extension Animation {
    /// Named springs, so motion feels consistent across the whole app.
    enum cortex {
        public static let standard: Animation = .spring(response: 0.4, dampingFraction: 0.78)
        public static let bouncy: Animation = .spring(response: 0.55, dampingFraction: 0.7)
        public static let snappy: Animation = .spring(response: 0.25, dampingFraction: 0.85)
    }
}

// MARK: - Aurora background

/// Five large blurred blobs that breathe, drift and color-shift over time,
/// layered with procedural noise + a dynamic vignette. Pure SwiftUI, no assets.
///
/// **Performance:** the blobs animate at 60fps while the app is key, dropping to
/// ~10fps when it loses focus — identical look, a fraction of the CPU/GPU when
/// idle in the background.
public struct AuroraBackground: View {
    public var intensity: Double
    @State private var active = NSApp?.isActive ?? true

    public init(intensity: Double = 1.0) { self.intensity = intensity }

    public var body: some View {
        let interval = active ? 1.0 / 60.0 : 1.0 / 10.0
        TimelineView(.animation(minimumInterval: interval)) { ctx in
            let now = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Color.black

                blob(now: now, period: 11, radius: 600, baseX: -200, baseY: -150,
                     drift: 80, color: Brand.palette[0], phase: 0)
                blob(now: now, period: 14, radius: 540, baseX: 220, baseY: -60,
                     drift: 70, color: Brand.palette[1], phase: 1.3)
                blob(now: now, period: 9, radius: 460, baseX: 100, baseY: 220,
                     drift: 90, color: Brand.palette[2], phase: 2.7)
                blob(now: now, period: 17, radius: 520, baseX: -160, baseY: 200,
                     drift: 60, color: Brand.palette[3], phase: 4.1)
                blob(now: now, period: 21, radius: 380, baseX: 280, baseY: 260,
                     drift: 50, color: Brand.palette[4], phase: 5.6)

                NoiseOverlay()
                    .blendMode(.softLight)
                    .opacity(0.18)

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.55 + 0.06 * sin(now / 6))],
                            center: .center, startRadius: 220, endRadius: 900
                        )
                    )
            }
            .compositingGroup()
            .opacity(intensity)
        }
        .id(active)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in active = true }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in active = false }
    }

    private func blob(
        now: TimeInterval, period: Double, radius: CGFloat,
        baseX: CGFloat, baseY: CGFloat, drift: CGFloat,
        color: Color, phase: Double
    ) -> some View {
        let p = (now / period + phase).truncatingRemainder(dividingBy: 1)
        let angle = p * .pi * 2
        let x = baseX + drift * CGFloat(cos(angle))
        let y = baseY + drift * CGFloat(sin(angle * 1.3))
        let scale = 1.0 + 0.15 * CGFloat(sin(angle * 2))
        let alpha = 0.42 + 0.10 * sin(angle * 1.7)
        return Circle()
            .fill(color)
            .frame(width: radius, height: radius)
            .scaleEffect(scale)
            .blur(radius: 110)
            .offset(x: x, y: y)
            .opacity(alpha)
            .blendMode(.screen)
    }
}

/// A field of faint, deterministic specks layered over the Aurora to break up
/// the gradient banding. Deterministic (seeded) so it doesn't shimmer per frame.
public struct NoiseOverlay: View {
    public init() {}
    public var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: 0x9E3779B97F4A7C15)
            for _ in 0..<600 {
                let x = CGFloat(rng.nextUnit()) * size.width
                let y = CGFloat(rng.nextUnit()) * size.height
                let r = 0.5 + CGFloat(rng.nextUnit()) * 0.8
                let a = 0.04 + Double(rng.nextUnit()) * 0.10
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fast, seedable PRNG for the noise field — no `Foundation` random, so the
/// pattern is identical every launch (and cheap).
private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
