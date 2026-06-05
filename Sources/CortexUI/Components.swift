import SwiftUI

// MARK: - Shimmer hero text

/// A headline whose fill is the brand gradient with a highlight sweeping across
/// it forever — the family's "hero" title treatment.
public struct ShimmerText: View {
    public let text: String
    public var size: CGFloat
    public var weight: Font.Weight
    public var design: Font.Design

    public init(_ text: String, size: CGFloat = 38, weight: Font.Weight = .bold, design: Font.Design = .rounded) {
        self.text = text
        self.size = size
        self.weight = weight
        self.design = design
    }

    private var font: Font { .system(size: size, weight: weight, design: design) }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let p = CGFloat((t / 3).truncatingRemainder(dividingBy: 1)) * 1.6 - 0.3
            Text(text)
                .font(font)
                .foregroundStyle(.clear)
                .overlay(
                    ZStack {
                        LinearGradient(
                            colors: [Brand.palette[0], Brand.palette[1], Brand.palette[2]],
                            startPoint: .leading, endPoint: .trailing
                        )
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: max(0, p - 0.15)),
                                .init(color: .white.opacity(0.85), location: max(0, min(1, p))),
                                .init(color: .clear, location: min(1, p + 0.15)),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .blendMode(.plusLighter)
                    }
                    .mask(Text(text).font(font))
                )
        }
    }
}

// MARK: - Status dot with pulsing halo

/// A small filled dot with a softly pulsing halo — connection/health status.
public struct StatusDot: View {
    public let color: Color
    public var size: CGFloat

    public init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 2))
            ZStack {
                Circle()
                    .fill(color.opacity(0.5 * pulse))
                    .frame(width: size * 3, height: size * 3)
                    .blur(radius: 6)
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Cascade entrance

/// Staggered entrance: views fade/slide/scale in with a per-item delay. Apply
/// with increasing `delay` down a list for the family's signature cascade.
public struct CascadeModifier: ViewModifier {
    public let delay: Double
    public let distance: CGFloat
    @State private var appeared = false

    public init(delay: Double, distance: CGFloat = 18) {
        self.delay = delay
        self.distance = distance
    }

    public func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : distance)
            .scaleEffect(appeared ? 1 : 0.985, anchor: .top)
            .blur(radius: appeared ? 0 : 4)
            .onAppear { withAnimation(.cortex.bouncy.delay(delay)) { appeared = true } }
    }
}

public extension View {
    func cascade(delay: Double, distance: CGFloat = 18) -> some View {
        modifier(CascadeModifier(delay: delay, distance: distance))
    }
}

// MARK: - Button styles

/// Scales the label down slightly while pressed — a subtle tactile press.
public struct PressableStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.cortex.snappy, value: configuration.isPressed)
    }
}

/// The family's primary call-to-action: a gradient pill with a glow.
public struct GradientButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Brand.palette[0], Brand.palette[2]],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Brand.accent.opacity(0.5), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.cortex.snappy, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == GradientButtonStyle {
    static var gradient: GradientButtonStyle { GradientButtonStyle() }
}

public extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}
