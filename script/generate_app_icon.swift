import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconSizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not render \(name)")
    }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawIcon(in: CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(name)")
    }
    try png.write(to: outputDirectory.appendingPathComponent(name))
}

try writeICNS(from: outputDirectory, to: outputDirectory.deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))

func drawIcon(in rect: CGRect) {
    let cornerRadius = rect.width * 0.225
    let bounds = rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.035)
    let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

    NSColor(calibratedRed: 0.045, green: 0.055, blue: 0.065, alpha: 1).setFill()
    backgroundPath.fill()

    NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.78, alpha: 1).setStroke()
    backgroundPath.lineWidth = max(2, rect.width * 0.028)
    backgroundPath.stroke()

    let text = "AU" as NSString
    let font = NSFont.systemFont(ofSize: rect.width * 0.34, weight: .bold)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.28, green: 0.96, blue: 0.90, alpha: 1),
        .paragraphStyle: paragraph,
        .kern: -rect.width * 0.006
    ]
    let textSize = text.size(withAttributes: attributes)
    let textRect = CGRect(
        x: rect.midX - textSize.width / 2,
        y: rect.midY - textSize.height / 2 - rect.height * 0.01,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attributes)
}

func writeICNS(from iconset: URL, to output: URL) throws {
    let entries: [(String, String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic14", "icon_256x256@2x.png")
    ]

    var body = Data()
    for (type, filename) in entries {
        let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
        body.append(type.data(using: .macOSRoman)!)
        body.append(bigEndianUInt32(UInt32(png.count + 8)))
        body.append(png)
    }

    var file = Data()
    file.append("icns".data(using: .macOSRoman)!)
    file.append(bigEndianUInt32(UInt32(body.count + 8)))
    file.append(body)
    try file.write(to: output, options: .atomic)
}

func bigEndianUInt32(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}
