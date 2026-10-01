// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 NoisyQubits

import SwiftUI

struct FileSpokeAppearanceView: View {
    let close: () -> Void
    @ObservedObject private var settings = AppearanceSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Preferences").font(.system(size: 25, weight: .semibold))
                Text("Adjust the radial menu, then choose the menu bar symbol.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            radialControls
            Text("Icon").font(.headline)
            HStack(spacing: 12) {
                ForEach(FileSpokeMenuIcon.allCases) { icon in
                    iconChoice(icon)
                }
            }
            Text("The icon stays monochrome so macOS can keep it legible in the menu bar.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Text("FileSpoke always follows your macOS appearance and accent color.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: close).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
        .tint(settings.theme.accent)
        .preferredColorScheme(settings.theme.scheme)
    }

    private var radialControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Radial menu").font(.headline)
                Spacer()
                Button("Reset", action: settings.resetRadialSizing)
                    .buttonStyle(.borderless)
            }
            sliderRow(title: "Size", value: $settings.radialScale, range: 0.9...1.45)
            sliderRow(title: "Label size", value: $settings.radialFontScale, range: 0.8...1.6)
            Text("Changes apply the next time you start a Finder drag.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 76, alignment: .leading)
            Slider(value: value, in: range, step: 0.05)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .monospacedDigit().frame(width: 42, alignment: .trailing)
        }
    }

    private func iconChoice(_ icon: FileSpokeMenuIcon) -> some View {
        let selected = settings.menuIcon == icon
        return Button { settings.menuIcon = icon } label: {
            VStack(spacing: 8) {
                Image(systemName: icon.symbol).font(.system(size: 22, weight: .medium))
                    .frame(width: 42, height: 42)
                Text(icon.name).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(settings.theme.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? settings.theme.accent : settings.theme.border,
                                                               lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(icon.name) menu bar icon")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
