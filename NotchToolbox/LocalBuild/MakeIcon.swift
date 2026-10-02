import AppKit
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
func render(_ size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size)/1024, y: CGFloat(size)/1024)
    let card = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 208, yRadius: 208)
    NSGradient(colors: [NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.15, alpha: 1),
                        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.30, alpha: 1)])!.draw(in: card, angle: 65)
    NSColor(calibratedWhite: 1, alpha: 0.13).setStroke(); card.lineWidth = 8; card.stroke()
    let n = NSBezierPath()
    n.move(to: NSPoint(x: 278,y: 276)); n.line(to: NSPoint(x: 278,y: 748)); n.line(to: NSPoint(x: 384,y: 748))
    n.line(to: NSPoint(x: 640,y: 447)); n.line(to: NSPoint(x: 640,y: 748)); n.line(to: NSPoint(x: 746,y: 748))
    n.line(to: NSPoint(x: 746,y: 276)); n.line(to: NSPoint(x: 640,y: 276)); n.line(to: NSPoint(x: 384,y: 577))
    n.line(to: NSPoint(x: 384,y: 276)); n.close()
    NSGradient(colors: [NSColor(calibratedRed: 0.29, green: 0.40, blue: 1, alpha: 1),
                        NSColor(calibratedRed: 0.29, green: 0.91, blue: 0.91, alpha: 1)])!.draw(in: n, angle: 65)
    let notch = NSBezierPath(roundedRect: NSRect(x: 363,y: 832,width: 298,height: 128),xRadius: 43,yRadius:43)
    NSColor(calibratedRed:0.035,green:0.045,blue:0.075,alpha:1).setFill();notch.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for size in [16,32,128,256,512] {
    try render(size).write(to: out.appending(path:"icon_\(size)x\(size).png"))
    try render(size*2).write(to: out.appending(path:"icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to: out.deletingLastPathComponent().appending(path:"NotchHubLogo.png"))
