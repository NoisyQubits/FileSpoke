// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 NoisyQubits

import AppKit
import ImageIO
import PDFKit

enum FileSpokeSelftest {
    static func run() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileSpoke-selftest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let png = root.appendingPathComponent("sample.png")
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: 32, height: 24, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let writer = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(NSColor.systemOrange.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        guard let image = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(writer, image, nil)
        guard CGImageDestinationFinalize(writer) else { throw CocoaError(.fileWriteUnknown) }
        let original = try Data(contentsOf: png)

        let pdf = try FileDragConversionEngine.convert(png, to: .pdf, batch: FileDragBatch())
        guard pdf != png, PDFDocument(url: pdf)?.pageCount == 1,
              try Data(contentsOf: png) == original else { throw CocoaError(.fileWriteUnknown) }

        let text = root.appendingPathComponent("notes.txt")
        try "FileSpoke local conversion\nSecond line".write(to: text, atomically: true, encoding: .utf8)
        let textPDF = try FileDragConversionEngine.convert(text, to: .pdf, batch: FileDragBatch())
        guard PDFDocument(url: textPDF)?.pageCount == 1 else { throw CocoaError(.fileWriteUnknown) }

        let plan = try PDFTools.plan([pdf, textPDF])
        let merged = try PDFTools.save(plan, tool: .merge, batch: FileDragBatch())
        guard PDFDocument(url: merged)?.pageCount == 2 else { throw CocoaError(.fileWriteUnknown) }

        let archiveSource = root.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: archiveSource, withIntermediateDirectories: true)
        try "archive payload".write(to: archiveSource.appendingPathComponent("item.txt"), atomically: true, encoding: .utf8)
        let tar = root.appendingPathComponent("payload.tar")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-cf", tar.path, "-C", root.path, "payload"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
        let zip = try FileArchiveTools.convert(tar, to: .zip, batch: FileDragBatch())
        let unpacked = try FileArchiveTools.extract(zip, batch: FileDragBatch())
        let roundTrip = unpacked.appendingPathComponent("payload/item.txt")
        guard try String(contentsOf: roundTrip, encoding: .utf8) == "archive payload" else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let engines = MediaEngineBundle.bundled else { throw CocoaError(.executableNotLoadable) }
        let wav = root.appendingPathComponent("tone.wav")
        try makeWAV(to: wav)
        let mp3 = try FileDragConversionEngine.convert(wav, to: .mp3, batch: FileDragBatch(), engines: engines)
        guard ((try? mp3.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) > 100 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func makeWAV(to url: URL) throws {
        let rate = 8_000, frames = 2_000
        let pcm = (0..<frames).flatMap { index -> [UInt8] in
            let wave = sin(Double(index) * 2 * .pi * 440 / Double(rate)) * 8_000
            let value = UInt16(bitPattern: Int16(wave))
            return [UInt8(value & 0xff), UInt8(value >> 8)]
        }
        var bytes = Data()
        func word(_ value: UInt32) { for shift in [0, 8, 16, 24] { bytes.append(UInt8((value >> shift) & 0xff)) } }
        func short(_ value: UInt16) { bytes.append(UInt8(value & 0xff)); bytes.append(UInt8(value >> 8)) }
        bytes.append(contentsOf: Array("RIFF".utf8)); word(UInt32(36 + pcm.count))
        bytes.append(contentsOf: Array("WAVEfmt ".utf8)); word(16)
        short(1); short(1); word(UInt32(rate)); word(UInt32(rate * 2)); short(2); short(16)
        bytes.append(contentsOf: Array("data".utf8)); word(UInt32(pcm.count)); bytes.append(contentsOf: pcm)
        try bytes.write(to: url)
    }
}
