import SwiftUI

/// A shimmering placeholder bar shown while content loads — the gradient sweeps
/// left → right forever, signalling "loading" instead of an empty column.
public struct SkeletonRow: View {
    public var width: CGFloat
    public var height: CGFloat
    @State private var phase: CGFloat = -0.5

    public init(width: CGFloat = 160, height: CGFloat = 10) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.05), location: 0),
                        .init(color: .white.opacity(0.18), location: 0.5),
                        .init(color: .white.opacity(0.05), location: 1),
                    ],
                    startPoint: UnitPoint(x: phase, y: 0.5),
                    endPoint: UnitPoint(x: phase + 1, y: 0.5)
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

/// A short column of skeleton rows with varied widths — drop into a sidebar's
/// loading branch.
public struct SkeletonList: View {
    public var rows: Int
    public var widths: [CGFloat]

    public init(rows: Int = 6, widths: [CGFloat] = [140, 110, 160, 90, 130, 100]) {
        self.rows = rows
        self.widths = widths
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0 ..< rows, id: \.self) { idx in
                SkeletonRow(width: widths[idx % widths.count])
            }
        }
        .padding(.horizontal, 14).padding(.top, 12)
    }
}
