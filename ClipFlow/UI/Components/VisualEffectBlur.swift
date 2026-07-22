import AppKit
import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blendingMode
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension View {
    /// Keeps grouped forms visually integrated with the settings detail column.
    /// `Form` owns a scroll background on macOS, which becomes an opaque rectangle
    /// when the form is already hosted by the settings scroll view.
    func clipFlowSettingsFormStyle() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, -8)
    }

    /// Semantic card surface that follows macOS appearance and accessibility
    /// contrast instead of relying on translucent material over an unknown layer.
    func clipFlowSettingsSurface(cornerRadius: CGFloat = 12) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                }
        )
    }
}
