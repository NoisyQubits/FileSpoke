// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 NoisyQubits

import AppKit
import SwiftUI

/// FileSpoke deliberately inherits its appearance and accent color from macOS.
enum FileSpokeTheme {
    case system

    var scheme: ColorScheme? {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    var accent: Color { Color(nsColor: .controlAccentColor) }
    var base: Color { Color(nsColor: .windowBackgroundColor) }
    var card: Color { Color(nsColor: .controlBackgroundColor) }
    var foreground: Color { Color(nsColor: .labelColor) }
    var border: Color { Color(nsColor: .separatorColor) }
    var wheelInactive: [Color] { [card, base] }
}

enum FileSpokeMenuIcon: String, CaseIterable, Identifiable {
    case convert, spokes, documents, layers

    var id: String { rawValue }

    var name: String {
        switch self {
        case .convert: "Convert"
        case .spokes: "Spokes"
        case .documents: "Documents"
        case .layers: "Layers"
        }
    }

    var symbol: String {
        switch self {
        case .convert: "arrow.triangle.2.circlepath"
        case .spokes: "circle.hexagongrid.fill"
        case .documents: "doc.on.doc.fill"
        case .layers: "square.stack.3d.up.fill"
        }
    }
}

final class AppearanceSettings: ObservableObject {
    static let shared = AppearanceSettings()

    static let defaultRadialScale = 1.25
    static let defaultRadialFontScale = 1.0

    @Published private(set) var systemRevision = 0
    private var systemColorObserver: NSObjectProtocol?
    private var effectiveAppearanceObserver: NSKeyValueObservation?

    var theme: FileSpokeTheme { .system }
    @Published var menuIcon: FileSpokeMenuIcon {
        didSet { UserDefaults.standard.set(menuIcon.rawValue, forKey: DefaultsKey.menuBarIcon) }
    }
    @Published var radialScale: Double {
        didSet { UserDefaults.standard.set(radialScale, forKey: DefaultsKey.radialScale) }
    }
    @Published var radialFontScale: Double {
        didSet { UserDefaults.standard.set(radialFontScale, forKey: DefaultsKey.radialFontScale) }
    }

    private init() {
        menuIcon = FileSpokeMenuIcon(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.menuBarIcon) ?? "") ?? .convert
        radialScale = Self.preference(DefaultsKey.radialScale, defaultValue: Self.defaultRadialScale, range: 0.9...1.45)
        radialFontScale = Self.preference(DefaultsKey.radialFontScale, defaultValue: Self.defaultRadialFontScale, range: 0.8...1.6)
        systemColorObserver = NotificationCenter.default.addObserver(
            forName: NSColor.systemColorsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.systemRevision += 1 }
        effectiveAppearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.systemRevision += 1 }
        }
    }

    deinit {
        if let systemColorObserver { NotificationCenter.default.removeObserver(systemColorObserver) }
    }

    func resetRadialSizing() {
        radialScale = Self.defaultRadialScale
        radialFontScale = Self.defaultRadialFontScale
    }

    private static func preference(_ key: String, defaultValue: Double, range: ClosedRange<Double>) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return min(max(UserDefaults.standard.double(forKey: key), range.lowerBound), range.upperBound)
    }
}
