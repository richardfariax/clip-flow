import AppKit
import SwiftUI

struct BrandLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = NSImage(named: logoAssetName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.13, green: 0.19, blue: 0.36),
                                    Color(red: 0.06, green: 0.08, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "c.circle.fill")
                        .font(.system(size: size * 0.62, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.70, green: 0.86, blue: 1.00),
                                    Color(red: 0.53, green: 0.58, blue: 1.00),
                                    Color(red: 0.67, green: 0.50, blue: 1.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private var logoAssetName: String {
        colorScheme == .dark ? "ClipFlowLogoDark" : "ClipFlowLogoLight"
    }
}
