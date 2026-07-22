import AppKit
import SwiftUI

struct BrandLogoView: View {
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.48, blue: 0.96),
                            Color(red: 0.39, green: 0.22, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = NSImage(named: "ClipFlowMark") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.17)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(.white)
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
}
