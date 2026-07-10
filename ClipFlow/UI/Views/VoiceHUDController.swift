import AppKit
import SwiftUI

@MainActor
final class VoiceHUDModel: ObservableObject {
    enum Phase: Equatable {
        case listening
        case feedback(message: String, success: Bool)
    }

    @Published var phase: Phase = .listening
    @Published var transcript: String = ""
    @Published var hintText: String = ""
}

/// Overlay de tela cheia (transparente e click-through) exibido durante a
/// interação por voz — estilo "Jarvis": orbe central, brackets de canto,
/// anéis decorativos e linha de varredura.
@MainActor
final class VoiceHUDController {
    /// Sons nativos do sistema para feedback audível.
    private enum FeedbackSound: String {
        case wake = "Pop"
        case success = "Glass"
        case failure = "Basso"
    }

    /// Injetado pelo AppDelegate; controlado por settings.voiceSoundFeedback.
    var isSoundEnabled: () -> Bool = { true }

    private var panel: NSPanel?
    private let model = VoiceHUDModel()
    private var hideWorkItem: DispatchWorkItem?

    func showListening(hint: String) {
        hideWorkItem?.cancel()
        model.phase = .listening
        model.transcript = ""
        model.hintText = hint
        presentPanel()
        play(.wake)
    }

    func updateTranscript(_ transcript: String) {
        model.transcript = transcript
    }

    /// - Parameter autoHide: quando false, o overlay permanece até `hide()`
    ///   ser chamado (ex.: ao término da resposta falada).
    func showFeedback(message: String, success: Bool, autoHide: Bool = true) {
        model.phase = .feedback(message: message, success: success)
        presentPanel()
        play(success ? .success : .failure)
        if autoHide {
            scheduleHide(after: 2.6)
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.28
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func play(_ sound: FeedbackSound) {
        guard isSoundEnabled() else { return }
        NSSound(named: sound.rawValue)?.play()
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func presentPanel() {
        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }

        panel.setFrame(activeScreenFrame(), display: true)

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
        }
    }

    private func makePanel() -> NSPanel {
        let hosting = NSHostingView(rootView: VoiceHUDView(model: model))

        let panel = NSPanel(
            contentRect: activeScreenFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        return panel
    }

    private func activeScreenFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
        return screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

// MARK: - View

struct VoiceHUDView: View {
    @ObservedObject var model: VoiceHUDModel

    var body: some View {
        ZStack {
            JarvisBackdropView(color: themeColor, isActive: isListening)

            VStack(spacing: 28) {
                Spacer()

                JarvisOrbView(color: themeColor, isActive: isListening)
                    .frame(width: 190, height: 190)

                messageCard

                Spacer()
                    .frame(height: 90)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.35), value: themeColorKey)
    }

    private var messageCard: some View {
        Group {
            switch model.phase {
            case .listening:
                Text(model.transcript.isEmpty ? model.hintText : model.transcript)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(model.transcript.isEmpty ? .secondary : .primary)
                    .lineLimit(3)
            case .feedback(let message, _):
                Text(message)
                    .font(.title3.weight(.medium))
                    .lineLimit(5)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: themeColor.opacity(0.3), radius: 22)
        )
    }

    private var isListening: Bool {
        if case .listening = model.phase { return true }
        return false
    }

    private var themeColor: Color {
        switch model.phase {
        case .listening:
            return .cyan
        case .feedback(_, let success):
            return success ? .green : .orange
        }
    }

    private var themeColorKey: Int {
        switch model.phase {
        case .listening: return 0
        case .feedback(_, let success): return success ? 1 : 2
        }
    }
}

// MARK: - Backdrop de tela cheia

/// Elementos decorativos de tela cheia: brackets de canto, anéis laterais
/// e linha de varredura — tudo transparente e discreto.
private struct JarvisBackdropView: View {
    let color: Color
    let isActive: Bool

    @State private var scan = false
    @State private var rotate = false
    @State private var glowPulse = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // Vinheta sutil nas bordas para dar profundidade
                RadialGradient(
                    colors: [.clear, .clear, color.opacity(0.10)],
                    center: .center,
                    startRadius: min(size.width, size.height) * 0.25,
                    endRadius: max(size.width, size.height) * 0.72
                )
                .opacity(glowPulse ? 1.0 : 0.55)

                // Brackets nos quatro cantos
                cornerBrackets(in: size)

                // Anéis decorativos gigantes e tênues atrás do centro
                Circle()
                    .stroke(color.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [2, 14]))
                    .frame(width: size.height * 0.85, height: size.height * 0.85)
                    .position(x: size.width / 2, y: size.height / 2)
                    .rotationEffect(.degrees(rotate ? 360 : 0))

                Circle()
                    .stroke(color.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [40, 26]))
                    .frame(width: size.height * 0.58, height: size.height * 0.58)
                    .position(x: size.width / 2, y: size.height / 2)
                    .rotationEffect(.degrees(rotate ? -360 : 0))

                // Linha de varredura horizontal
                LinearGradient(
                    colors: [.clear, color.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 2)
                .frame(maxWidth: size.width * 0.7)
                .position(x: size.width / 2, y: scan ? size.height * 0.82 : size.height * 0.18)
                .opacity(isActive ? 0.9 : 0.35)

                // Marcadores laterais (tique de régua)
                sideTicks(in: size)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                scan = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private func cornerBrackets(in size: CGSize) -> some View {
        let inset: CGFloat = 42
        let arm: CGFloat = 56

        return ZStack {
            bracket(arm: arm)
                .position(x: inset + arm / 2, y: inset + arm / 2)
            bracket(arm: arm)
                .rotationEffect(.degrees(90))
                .position(x: size.width - inset - arm / 2, y: inset + arm / 2)
            bracket(arm: arm)
                .rotationEffect(.degrees(270))
                .position(x: inset + arm / 2, y: size.height - inset - arm / 2)
            bracket(arm: arm)
                .rotationEffect(.degrees(180))
                .position(x: size.width - inset - arm / 2, y: size.height - inset - arm / 2)
        }
        .opacity(glowPulse ? 0.85 : 0.5)
    }

    /// Bracket em "L" (canto superior esquerdo; os demais são rotações).
    private func bracket(arm: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: arm))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: arm, y: 0))
        }
        .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: arm, height: arm)
        .shadow(color: color.opacity(0.7), radius: 6)
    }

    private func sideTicks(in size: CGSize) -> some View {
        let tickCount = 9

        return ZStack {
            VStack(spacing: (size.height * 0.5) / CGFloat(tickCount)) {
                ForEach(0..<tickCount, id: \.self) { index in
                    Rectangle()
                        .fill(color.opacity(index % 3 == 0 ? 0.55 : 0.25))
                        .frame(width: index % 3 == 0 ? 22 : 12, height: 1.5)
                }
            }
            .position(x: 30, y: size.height / 2)

            VStack(spacing: (size.height * 0.5) / CGFloat(tickCount)) {
                ForEach(0..<tickCount, id: \.self) { index in
                    Rectangle()
                        .fill(color.opacity(index % 3 == 0 ? 0.55 : 0.25))
                        .frame(width: index % 3 == 0 ? 22 : 12, height: 1.5)
                }
            }
            .position(x: size.width - 30, y: size.height / 2)
        }
    }
}

// MARK: - Orbe central

/// Orbe animado estilo "arc reactor": anéis tracejados contra-rotativos
/// em volta de um núcleo pulsante com glow.
private struct JarvisOrbView: View {
    let color: Color
    let isActive: Bool

    @State private var rotate = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Glow difuso de fundo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.45), color.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 95
                    )
                )
                .scaleEffect(pulse ? 1.1 : 0.88)

            // Anel externo tracejado (horário)
            Circle()
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [26, 14]))
                .frame(width: 158, height: 158)
                .rotationEffect(.degrees(rotate ? 360 : 0))

            // Anel intermediário (anti-horário)
            Circle()
                .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 16]))
                .frame(width: 122, height: 122)
                .rotationEffect(.degrees(rotate ? -360 : 0))

            // Arcos de progresso internos (horário, mais rápido)
            Circle()
                .trim(from: 0, to: 0.26)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(rotate ? 720 : 0))

            Circle()
                .trim(from: 0.5, to: 0.68)
                .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(rotate ? 720 : 0))

            // Núcleo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, color.opacity(0.9), color.opacity(0.3)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 26
                    )
                )
                .frame(width: 44, height: 44)
                .scaleEffect(pulse ? 1.18 : 0.86)
                .shadow(color: color.opacity(0.9), radius: pulse ? 22 : 9)
        }
        .drawingGroup()
        .onAppear {
            startAnimations()
        }
        .onChange(of: isActive, initial: false) { _, _ in
            startAnimations()
        }
    }

    private func startAnimations() {
        rotate = false
        pulse = false
        withAnimation(.linear(duration: isActive ? 5 : 12).repeatForever(autoreverses: false)) {
            rotate = true
        }
        withAnimation(.easeInOut(duration: isActive ? 0.8 : 1.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
