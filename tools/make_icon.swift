import Cocoa
// 畫選單列圖示：圓角方塊裡一個「混」字
let px = 36
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: 18, height: 18)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.black.setFill()
NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 16, height: 16), xRadius: 3.5, yRadius: 3.5).fill()
let s = NSAttributedString(string: "混", attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor.white])
let size = s.size()
s.draw(at: NSPoint(x: (18 - size.width) / 2, y: (18 - size.height) / 2))
NSGraphicsContext.current?.flushGraphics()
try! rep.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
