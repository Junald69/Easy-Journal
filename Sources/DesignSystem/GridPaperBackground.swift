import SwiftUI

/// 紙の色の上に、方眼の線を描く背景。
///
/// 引数はありません。画面の端まで広がります。読み上げはしません。
/// 線の濃さは仮です。実機で見て調整します。
struct GridPaperBackground: View {
    var body: some View {
        Canvas { context, size in
            let area = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.fill(Path(area), with: .color(DesignTokens.paper))

            let spacing = DesignTokens.gridSize
            guard spacing > 0 else { return }

            var lines = Path()
            var x: CGFloat = 0
            while x <= size.width {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(lines, with: .color(DesignTokens.grid), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
