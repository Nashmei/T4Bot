#!/bin/bash
set -euo pipefail

ICON_DIR="T4Bot/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICON_DIR"

cat > "$RUNNER_TEMP/t4bot_icon.swift" <<'SWIFT'
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

let card = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 190, yRadius: 190)
NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.24, alpha: 1).setFill()
card.fill()

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 250, weight: .black),
    .foregroundColor: NSColor(calibratedWhite: 0.97, alpha: 1)
]
let text = NSAttributedString(string: "T4", attributes: attrs)
let textSize = text.size()
text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: 1024 - 245 - textSize.height))

let pulse = NSBezierPath()
pulse.lineWidth = 36
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
pulse.move(to: NSPoint(x: 190, y: 414))
pulse.line(to: NSPoint(x: 310, y: 414))
pulse.line(to: NSPoint(x: 370, y: 554))
pulse.line(to: NSPoint(x: 440, y: 324))
pulse.line(to: NSPoint(x: 520, y: 654))
pulse.line(to: NSPoint(x: 610, y: 414))
pulse.line(to: NSPoint(x: 830, y: 414))
NSColor(calibratedRed: 0.12, green: 0.48, blue: 1.0, alpha: 1).setStroke()
pulse.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Unable to render T4Bot app icon")
}

try png.write(to: URL(fileURLWithPath: "T4Bot/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
SWIFT

swift "$RUNNER_TEMP/t4bot_icon.swift"

SOURCE="$ICON_DIR/AppIcon.png"
test -s "$SOURCE"

make_icon() {
  local px="$1" out="$2"
  /usr/bin/sips -z "$px" "$px" "$SOURCE" --out "$ICON_DIR/$out" >/dev/null
}

make_icon 40  "Icon-20@2x.png"
make_icon 60  "Icon-20@3x.png"
make_icon 58  "Icon-29@2x.png"
make_icon 87  "Icon-29@3x.png"
make_icon 80  "Icon-40@2x.png"
make_icon 120 "Icon-40@3x.png"
make_icon 120 "Icon-60@2x.png"
make_icon 180 "Icon-60@3x.png"

cat > "$ICON_DIR/Contents.json" <<'JSON'
{
  "images": [
    {"filename":"Icon-20@2x.png","idiom":"iphone","scale":"2x","size":"20x20"},
    {"filename":"Icon-20@3x.png","idiom":"iphone","scale":"3x","size":"20x20"},
    {"filename":"Icon-29@2x.png","idiom":"iphone","scale":"2x","size":"29x29"},
    {"filename":"Icon-29@3x.png","idiom":"iphone","scale":"3x","size":"29x29"},
    {"filename":"Icon-40@2x.png","idiom":"iphone","scale":"2x","size":"40x40"},
    {"filename":"Icon-40@3x.png","idiom":"iphone","scale":"3x","size":"40x40"},
    {"filename":"Icon-60@2x.png","idiom":"iphone","scale":"2x","size":"60x60"},
    {"filename":"Icon-60@3x.png","idiom":"iphone","scale":"3x","size":"60x60"},
    {"filename":"AppIcon.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}
  ],
  "info": {"author":"xcode","version":1}
}
JSON
