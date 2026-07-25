//
//  Created by Doğa Erdemir on 24.07.2026.
//

import UIKit

enum SimpleIconRenderer {
    private static let iconCanvasSize: CGFloat = 24
    private static let iconColor = UIColor(
        red: 105 / 255,
        green: 113 / 255,
        blue: 125 / 255,
        alpha: 1
    )

    static func image(from data: Data, size: CGFloat) -> UIImage? {
        guard size > 0,
              let source = String(data: data, encoding: .utf8),
              let pathData = pathData(in: source) else {
            return nil
        }
        var parser = SVGPathParser(pathData)
        guard let path = parser.makePath() else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
            .image { context in
                let padding = size * 0.1
                let scale = (size - padding * 2) / iconCanvasSize
                context.cgContext.translateBy(x: padding, y: padding)
                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.addPath(path)
                context.cgContext.setFillColor(iconColor.cgColor)
                context.cgContext.fillPath()
            }
    }

    private static func pathData(in source: String) -> String? {
        guard let pathStart = source.range(of: "<path"),
              let dataStart = source.range(
                  of: "d=\"",
                  range: pathStart.lowerBound..<source.endIndex
              ) else {
            return nil
        }
        let valueStart = dataStart.upperBound
        guard let valueEnd = source[valueStart...].firstIndex(of: "\"") else { return nil }
        return String(source[valueStart..<valueEnd])
    }
}

private struct SVGPathParser {
    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private let tokens: [Token]
    private var index = 0
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl: CGPoint?
    private var activeCommand: Character?

    init(_ source: String) {
        tokens = Self.tokenize(source)
    }

    mutating func makePath() -> CGPath? {
        guard !tokens.isEmpty else { return nil }
        let path = CGMutablePath()

        while index < tokens.count {
            if case let .command(command) = tokens[index] {
                activeCommand = command
                index += 1
            }
            guard let command = activeCommand else { return nil }
            let relative = command.isLowercase

            switch command.lowercased() {
            case "m":
                guard let destination = takePoint(relative: relative) else { return nil }
                current = destination
                subpathStart = destination
                path.move(to: destination)
                lastCubicControl = nil
                activeCommand = relative ? "l" : "L"

            case "l":
                guard let destination = takePoint(relative: relative) else { return nil }
                path.addLine(to: destination)
                current = destination
                lastCubicControl = nil

            case "h":
                guard let value = takeNumber() else { return nil }
                let destination = CGPoint(x: relative ? current.x + value : value, y: current.y)
                path.addLine(to: destination)
                current = destination
                lastCubicControl = nil

            case "v":
                guard let value = takeNumber() else { return nil }
                let destination = CGPoint(x: current.x, y: relative ? current.y + value : value)
                path.addLine(to: destination)
                current = destination
                lastCubicControl = nil

            case "c":
                guard let control1 = takePoint(relative: relative),
                      let control2 = takePoint(relative: relative),
                      let destination = takePoint(relative: relative) else {
                    return nil
                }
                path.addCurve(to: destination, control1: control1, control2: control2)
                current = destination
                lastCubicControl = control2

            case "s":
                let control1 = lastCubicControl.map {
                    CGPoint(x: current.x * 2 - $0.x, y: current.y * 2 - $0.y)
                } ?? current
                guard let control2 = takePoint(relative: relative),
                      let destination = takePoint(relative: relative) else {
                    return nil
                }
                path.addCurve(to: destination, control1: control1, control2: control2)
                current = destination
                lastCubicControl = control2

            case "a":
                guard let radiusX = takeNumber(),
                      let radiusY = takeNumber(),
                      let rotation = takeNumber(),
                      let largeArcValue = takeNumber(),
                      let sweepValue = takeNumber(),
                      let destination = takePoint(relative: relative) else {
                    return nil
                }
                addArc(
                    to: path,
                    from: current,
                    to: destination,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    rotation: rotation,
                    isLargeArc: largeArcValue != 0,
                    isSweep: sweepValue != 0
                )
                current = destination
                lastCubicControl = nil

            case "z":
                path.closeSubpath()
                current = subpathStart
                lastCubicControl = nil
                activeCommand = nil

            default:
                return nil
            }
        }
        return path.isEmpty ? nil : path
    }

    private mutating func takeNumber() -> CGFloat? {
        guard index < tokens.count, case let .number(value) = tokens[index] else { return nil }
        index += 1
        return value
    }

    private mutating func takePoint(relative: Bool) -> CGPoint? {
        guard let x = takeNumber(), let y = takeNumber() else { return nil }
        return CGPoint(
            x: relative ? current.x + x : x,
            y: relative ? current.y + y : y
        )
    }

    private func addArc(
        to path: CGMutablePath,
        from start: CGPoint,
        to end: CGPoint,
        radiusX originalRadiusX: CGFloat,
        radiusY originalRadiusY: CGFloat,
        rotation: CGFloat,
        isLargeArc: Bool,
        isSweep: Bool
    ) {
        var radiusX = abs(originalRadiusX)
        var radiusY = abs(originalRadiusY)
        guard radiusX > 0, radiusY > 0, start != end else {
            path.addLine(to: end)
            return
        }

        let angle = rotation * .pi / 180
        let cosine = cos(angle)
        let sine = sin(angle)
        let halfDeltaX = (start.x - end.x) / 2
        let halfDeltaY = (start.y - end.y) / 2
        let transformedX = cosine * halfDeltaX + sine * halfDeltaY
        let transformedY = -sine * halfDeltaX + cosine * halfDeltaY

        let radiiScale = transformedX * transformedX / (radiusX * radiusX)
            + transformedY * transformedY / (radiusY * radiusY)
        if radiiScale > 1 {
            let scale = sqrt(radiiScale)
            radiusX *= scale
            radiusY *= scale
        }

        let radiusXSquared = radiusX * radiusX
        let radiusYSquared = radiusY * radiusY
        let transformedXSquared = transformedX * transformedX
        let transformedYSquared = transformedY * transformedY
        let numerator = max(
            0,
            radiusXSquared * radiusYSquared
                - radiusXSquared * transformedYSquared
                - radiusYSquared * transformedXSquared
        )
        let denominator = radiusXSquared * transformedYSquared
            + radiusYSquared * transformedXSquared
        let direction: CGFloat = isLargeArc == isSweep ? -1 : 1
        let coefficient = denominator == 0 ? 0 : direction * sqrt(numerator / denominator)
        let centerTransformedX = coefficient * radiusX * transformedY / radiusY
        let centerTransformedY = coefficient * -radiusY * transformedX / radiusX
        let center = CGPoint(
            x: cosine * centerTransformedX - sine * centerTransformedY + (start.x + end.x) / 2,
            y: sine * centerTransformedX + cosine * centerTransformedY + (start.y + end.y) / 2
        )

        let startVector = CGPoint(
            x: (transformedX - centerTransformedX) / radiusX,
            y: (transformedY - centerTransformedY) / radiusY
        )
        let endVector = CGPoint(
            x: (-transformedX - centerTransformedX) / radiusX,
            y: (-transformedY - centerTransformedY) / radiusY
        )
        let startAngle = atan2(startVector.y, startVector.x)
        var deltaAngle = atan2(
            startVector.x * endVector.y - startVector.y * endVector.x,
            startVector.x * endVector.x + startVector.y * endVector.y
        )
        if !isSweep, deltaAngle > 0 {
            deltaAngle -= 2 * .pi
        } else if isSweep, deltaAngle < 0 {
            deltaAngle += 2 * .pi
        }

        let segmentCount = max(1, Int(ceil(abs(deltaAngle) / (.pi / 2))))
        let segmentAngle = deltaAngle / CGFloat(segmentCount)
        for segment in 0..<segmentCount {
            let angle0 = startAngle + CGFloat(segment) * segmentAngle
            let angle1 = angle0 + segmentAngle
            let curveFactor = 4 / 3 * tan((angle1 - angle0) / 4)
            let startUnit = CGPoint(x: cos(angle0), y: sin(angle0))
            let endUnit = CGPoint(x: cos(angle1), y: sin(angle1))
            let control1Unit = CGPoint(
                x: startUnit.x - curveFactor * startUnit.y,
                y: startUnit.y + curveFactor * startUnit.x
            )
            let control2Unit = CGPoint(
                x: endUnit.x + curveFactor * endUnit.y,
                y: endUnit.y - curveFactor * endUnit.x
            )
            path.addCurve(
                to: transformed(
                    endUnit,
                    center: center,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    cosine: cosine,
                    sine: sine
                ),
                control1: transformed(
                    control1Unit,
                    center: center,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    cosine: cosine,
                    sine: sine
                ),
                control2: transformed(
                    control2Unit,
                    center: center,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    cosine: cosine,
                    sine: sine
                )
            )
        }
    }

    private func transformed(
        _ point: CGPoint,
        center: CGPoint,
        radiusX: CGFloat,
        radiusY: CGFloat,
        cosine: CGFloat,
        sine: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: center.x + cosine * radiusX * point.x - sine * radiusY * point.y,
            y: center.y + sine * radiusX * point.x + cosine * radiusY * point.y
        )
    }

    private static func tokenize(_ source: String) -> [Token] {
        let bytes = Array(source.utf8)
        var tokens: [Token] = []
        var cursor = 0

        while cursor < bytes.count {
            let byte = bytes[cursor]
            if byte == 44 || byte == 32 || byte == 9 || byte == 10 || byte == 13 {
                cursor += 1
                continue
            }
            if (65...90).contains(byte) || (97...122).contains(byte) {
                tokens.append(.command(Character(UnicodeScalar(byte))))
                cursor += 1
                continue
            }

            let numberStart = cursor
            if byte == 43 || byte == 45 {
                cursor += 1
            }
            while cursor < bytes.count, (48...57).contains(bytes[cursor]) {
                cursor += 1
            }
            if cursor < bytes.count, bytes[cursor] == 46 {
                cursor += 1
                while cursor < bytes.count, (48...57).contains(bytes[cursor]) {
                    cursor += 1
                }
            }
            if cursor < bytes.count, bytes[cursor] == 69 || bytes[cursor] == 101 {
                cursor += 1
                if cursor < bytes.count, bytes[cursor] == 43 || bytes[cursor] == 45 {
                    cursor += 1
                }
                while cursor < bytes.count, (48...57).contains(bytes[cursor]) {
                    cursor += 1
                }
            }
            guard cursor > numberStart,
                  let value = Double(String(decoding: bytes[numberStart..<cursor], as: UTF8.self)) else {
                return []
            }
            tokens.append(.number(CGFloat(value)))
        }
        return tokens
    }
}

private extension Character {
    var isLowercase: Bool {
        String(self) == String(self).lowercased()
    }

    func lowercased() -> String {
        String(self).lowercased()
    }
}
