import Carbon
import Foundation

struct HotkeyPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32

    static let customID = "custom"

    static let all: [HotkeyPreset] = [
        HotkeyPreset(id: "opt_v", title: "Option + V (Padrão)", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)),
        HotkeyPreset(id: "cmd_shift_v", title: "Command + Shift + V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)),
        HotkeyPreset(id: "ctrl_opt_v", title: "Control + Option + V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey)),
        HotkeyPreset(id: "cmd_opt_v", title: "Command + Option + V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | optionKey)),
        HotkeyPreset(id: "opt_space", title: "Option + Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
    ]

    static func matching(keyCode: UInt32, modifiers: UInt32) -> HotkeyPreset? {
        all.first { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }
}

enum HotkeyFormatter {
    private static let keyCodeNameMap: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space"
    ]

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Command")
        }

        let keyName = keyCodeNameMap[keyCode] ?? "Key(\(keyCode))"
        parts.append(keyName)

        return parts.joined(separator: " + ")
    }
}
