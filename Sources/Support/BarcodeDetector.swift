// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Vision

enum BarcodeDetector {
    struct Code { let payload: String }

    static func decodeQR(_ image: CGImage) throws -> [Code] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .microQR]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap {
            guard let value = $0.payloadStringValue, !value.isEmpty else { return nil }
            return Code(payload: value)
        }
    }
}
