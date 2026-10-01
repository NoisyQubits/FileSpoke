// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 NoisyQubits

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@main
final class FileSpokeAppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: FileSpokeAppDelegate?
    private var statusItem: NSStatusItem!
    private var chooser: NSPanel?
    private var welcome: NSWindow?
    private var lastStatusWork: DispatchWorkItem?

    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            do {
                try FileSpokeSelftest.run()
                print("FILE SPOKE SELFTEST OK")
                Darwin.exit(0)
            } catch {
                fputs("FILE SPOKE SELFTEST FAILED: \(error)\n", stderr)
                Darwin.exit(1)
            }
        }
        let app = NSApplication.shared
        let delegate = FileSpokeAppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        UserDefaults.standard.register(defaults: [DefaultsKey.mediaDragConvertEnabled: true])
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "FileSpoke")
        statusItem.button?.image?.isTemplate = true
        updateMenu()
        FileDragConversionService.shared.syncWithPreferences()
        if !UserDefaults.standard.bool(forKey: "FileSpoke.hasOpenedWelcome") {
            showWelcome()
            UserDefaults.standard.set(true, forKey: "FileSpoke.hasOpenedWelcome")
        }
    }

    private func updateMenu() {
        let menu = NSMenu(title: "FileSpoke")
        let choose = NSMenuItem(title: "Choose Files…", action: #selector(chooseFiles), keyEquivalent: "o")
        choose.target = self
        menu.addItem(choose)
        let enabled = NSMenuItem(title: "Enable Finder Shift-drag", action: #selector(toggleDrag), keyEquivalent: "")
        enabled.target = self
        enabled.state = UserDefaults.standard.bool(forKey: DefaultsKey.mediaDragConvertEnabled) ? .on : .off
        menu.addItem(enabled)
        let help = NSMenuItem(title: "How to Use FileSpoke…", action: #selector(showWelcomeAction), keyEquivalent: "")
        help.target = self
        menu.addItem(help)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit FileSpoke", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func chooseFiles() {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = true
        picker.begin { [weak self] response in
            guard response == .OK else { return }
            self?.showChooser(for: picker.urls)
        }
    }

    @objc private func showWelcomeAction() { showWelcome() }

    private func showWelcome() {
        let window = welcome ?? NSWindow(contentRect: CGRect(x: 0, y: 0, width: 510, height: 360),
                                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "FileSpoke"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: FileSpokeWelcome(openFiles: { [weak self] in
            self?.welcome?.close()
            self?.chooseFiles()
        }))
        window.center()
        welcome = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func showChooser(for inputs: [URL]) {
        guard let kind = inputs.first.flatMap(FileDragFormat.inputKind(for:)),
              inputs.allSatisfy({ FileDragFormat.inputKind(for: $0) == kind }) else {
            showStatus(message: "Select files of the same kind")
            return
        }
        let formats: [FileDragFormat]
        switch kind {
        case .image:
            let identifiers = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
            formats = FileDragFormat.availableImageFormats(destinationTypes: identifiers) + [.webp, .avif, .svg, .docx]
        case .video: formats = [.mp4, .mov, .mkv, .webm, .avi, .wmv, .gif, .mp3]
        case .audio: formats = [.mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma]
        case .document: formats = [.docx, .jpeg, .png, .txt]
        case .text: formats = [.pdf, .jpeg, .png, .srt, .vtt]
        case .subtitle: formats = [.srt, .vtt, .txt]
        case .archive: formats = [.zip, .tar, .gzip, .rar]
        }
        let actions = formats.map(FileDragAction.convert) + FileToolCatalog.actions(for: inputs, enginesAvailable: MediaEngineBundle.bundled != nil)
        let panel = chooser ?? NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .resizable],
                                       backing: .buffered, defer: false)
        panel.title = "FileSpoke"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentViewController = NSHostingController(rootView: FileSpokeChooser(inputs: inputs, actions: actions) { [weak self] action in
            self?.chooser?.close()
            switch action {
            case .convert, .extractArchive:
                FileJobToolController.shared.open(inputs: inputs, action: action, requiresDragEnabled: false)
            case .pdfTool(let tool): PDFToolController.shared.open(inputs: inputs, tool: tool)
            case .imageTool(let tool): ImageFileToolController.shared.open(inputs: inputs, tool: tool)
            case .avTool(let tool): AVFileToolController.shared.open(inputs: inputs, tool: tool)
            case .metadata:
                if let input = inputs.first { FileMetadataToolController.shared.open(input: input) }
            case .readImageQR, .moreTools:
                FileToolCatalogController.shared.open(inputs: inputs)
            }
        })
        panel.setContentSize(NSSize(width: 470, height: 520))
        panel.center()
        chooser = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleDrag() {
        let next = !UserDefaults.standard.bool(forKey: DefaultsKey.mediaDragConvertEnabled)
        UserDefaults.standard.set(next, forKey: DefaultsKey.mediaDragConvertEnabled)
        FileDragConversionService.shared.syncWithPreferences()
        updateMenu()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func showStatus(message: String) {
        lastStatusWork?.cancel()
        statusItem.button?.title = String(message.prefix(34))
        statusItem.length = NSStatusItem.variableLength
        let work = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.title = ""
            self?.statusItem.length = NSStatusItem.squareLength
        }
        lastStatusWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

private struct FileSpokeWelcome: View {
    let openFiles: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("FileSpoke", systemImage: "circle.hexagongrid.fill")
                .font(.largeTitle.bold())
                .foregroundStyle(.tint)
            Text("Convert and edit files where they live.").font(.title3)
            Text("In Finder, drag one or more files while holding Shift. Drop onto a format on the wheel. Hold Shift and Option for editing tools. Copies are saved beside your original files.")
                .fixedSize(horizontal: false, vertical: true)
            Text("You can also choose files from the menu bar icon. FileSpoke works locally and keeps originals untouched.")
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                Spacer()
                Button("Choose Files…", action: openFiles)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 510, height: 360)
    }
}

private struct FileSpokeChooser: View {
    let inputs: [URL]
    let actions: [FileDragAction]
    let select: (FileDragAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a format or tool").font(.title2.bold())
            Text(inputs.map(\.lastPathComponent).joined(separator: ", "))
                .lineLimit(2).foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(actions) { action in
                        Button(action.title(L10n.shared.language)) { select(action) }
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                }
            }
        }
        .padding(22)
        .frame(minWidth: 430, minHeight: 430)
    }
}
