// Regenerates KeepingYouAwake/AppIcon.icns from the Icon Composer source:
//
//   swift scripts/render-app-icon.swift \
//     KeepingYouAwake/AppIcon.icon/Assets/AppIcon.svg KeepingYouAwake/AppIcon.icns
//
// Run it again whenever AppIcon.icon changes. The .icns is what builds made
// with Xcode < 26 ship (release.yml uses Xcode 16); Xcode 26 compiles
// AppIcon.icon itself and prefers that.
import AppKit

// Renders the fork's app icon for builds whose Xcode can't compile
// AppIcon.icon (Icon Composer needs Xcode 26): a macOS-style rounded
// square with the light fill from icon.json and the cup logo in the
// icon.json foreground colour.
let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: swift \(args[0]) <AppIcon.svg> <output.icns>\n".data(using: .utf8)!)
    exit(64)
}
let svgURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let outDir = FileManager.default.temporaryDirectory.appendingPathComponent("kya-app-icon-\(UUID().uuidString)")
guard let logo = NSImage(contentsOf: svgURL) else { fatalError("cannot load \(svgURL.path)") }

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
let fillTop = srgb(1.0, 0.95, 0.88)          // lighter end of the automatic gradient
let fillBottom = srgb(1.0, 0.92157, 0.80)    // icon.json "automatic-gradient"
let logoColor = srgb(1.0, 0.41961, 0.0)      // icon.json light-appearance logo fill

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = s / 1024.0
    // macOS icon grid: 824 pt body inset 100 pt, ~185 pt corner radius.
    let body = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * unit, yRadius: 185 * unit)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * unit)
    shadow.shadowBlurRadius = 20 * unit
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fillBottom.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: fillTop, ending: fillBottom)!.draw(in: shape, angle: -90)

    // Logo: the SVG is drawn on a 1024 canvas; place it inside the body
    // (icon.json translates it 14 pt down) and tint it.
    let logoRect = NSRect(x: body.minX, y: body.minY - 14 * unit * 0.8, width: body.width, height: body.height)
    let tinted = NSImage(size: logoRect.size)
    tinted.lockFocus()
    logo.draw(in: NSRect(origin: .zero, size: logoRect.size))
    logoColor.set()
    NSRect(origin: .zero, size: logoRect.size).fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(in: logoRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: outDir)
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed (\(iconutil.terminationStatus))\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(outputURL.path)")
