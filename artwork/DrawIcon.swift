import AppKit
let directory = "/Users/apple/ApexText/artwork/ApexText.iconset"
for (points, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let size = points * scale
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(size)/1024); transform.concat()
    let rect = NSRect(x: 60, y: 60, width: 904, height: 904)
    let path = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
    NSGradient(starting: NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.26, alpha: 1), ending: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.09, alpha: 1))!.draw(in: path, angle: -70)
    let base = NSFont.systemFont(ofSize: 183, weight: .heavy)
    let font = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
    let text = NSMutableAttributedString(string: "ApexText", attributes: [.font: font, .foregroundColor: NSColor.white, .kern: -8])
    text.addAttribute(.foregroundColor, value: NSColor(calibratedRed: 0.25, green: 0.69, blue: 1, alpha: 1), range: NSRange(location: 4, length: 4))
    let measured = text.size()
    text.draw(at: NSPoint(x: (1024-measured.width)/2, y: (1024-measured.height)/2+14))
    let underline = NSBezierPath(roundedRect: NSRect(x: 192, y: 307, width: 640, height: 13), xRadius: 6, yRadius: 6)
    NSColor(calibratedRed: 0.25, green: 0.69, blue: 1, alpha: 0.85).setFill(); underline.fill()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(directory)/icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"))
}
