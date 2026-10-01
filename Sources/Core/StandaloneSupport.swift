// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 NoisyQubits

import AppKit
import Combine
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case enUS = "en-US", ptBR = "pt-BR", tr, ru, es, sk, de, fr, it, ja, ko, uk
    case zhHans = "zh-Hans", zhTW = "zh-TW", zhHK = "zh-HK"
    var id: String { rawValue }
    func formattingLocale() -> Locale { Locale(identifier: rawValue) }
}

final class L10n: ObservableObject {
    static let shared = L10n()
    @Published var language: AppLanguage

    struct SharedStrings {
        let mediaSizingFileSize = "Target file size"
        let mediaCancelled = "Cancelled"
        let mediaRunAgain = "Retry failed files"
        let mediaQuality = "Quality"
        let mediaOutput = "Output"
        let mediaSelectFile = "Choose file"
    }
    var s: SharedStrings { SharedStrings() }

    private init() {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        language = AppLanguage.allCases.first { preferred.lowercased().hasPrefix($0.rawValue.lowercased()) } ?? .enUS
    }
}

enum DefaultsKey {
    static let mediaDragConvertEnabled = "FileSpoke.shiftDragEnabled"
    static let liquidGlassEnabled = "FileSpoke.liquidGlassEnabled"
}

enum AppFeature {
    case mediaTools
    var isAvailable: Bool { true }
}

enum PanelSurface {
    static func baseFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.68) : Color.black.opacity(0.42)
    }
    static func border(for scheme: ColorScheme) -> Color {
        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return scheme == .light ? Color.black.opacity(contrast ? 0.24 : 0.09)
                                : Color.white.opacity(contrast ? 0.28 : 0.11)
    }
    static func rimHighlight(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [Color.white.opacity(scheme == .light ? 0.95 : 0.30),
                                Color.white.opacity(scheme == .light ? 0.12 : 0.04)],
                       startPoint: .top, endPoint: .bottom)
    }
}

enum RadialMenuGeometry {
    static func highlightedIndex(dx: CGFloat, dyUp: CGFloat,
                                 deadZoneRadius: CGFloat, itemCount: Int) -> Int? {
        guard itemCount > 0, hypot(dx, dyUp) >= deadZoneRadius else { return nil }
        let raw = atan2(dx, dyUp)
        let angle = raw < 0 ? raw + 2 * .pi : raw
        let step = 2 * .pi / CGFloat(itemCount)
        return min(Int((angle + step / 2).truncatingRemainder(dividingBy: 2 * .pi) / step), itemCount - 1)
    }
    static func unitPosition(index: Int, itemCount: Int) -> (dx: CGFloat, dyUp: CGFloat) {
        guard itemCount > 0 else { return (0, 1) }
        let theta = 2 * .pi * CGFloat(index) / CGFloat(itemCount)
        return (sin(theta), cos(theta))
    }
}

final class QuickToolHUD {
    static func show(icon: String, message: String) {
        FileSpokeAppDelegate.shared?.showStatus(message: message)
    }
}
