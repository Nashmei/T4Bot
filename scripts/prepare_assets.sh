#!/bin/bash
set -euo pipefail

ICON_DIR="T4Bot/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICON_DIR"

cat > "$RUNNER_TEMP/t4bot_icon.swift" <<'SWIFT'
import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let bg = NSGradient(colors: [NSColor(calibratedRed:0.025,green:0.04,blue:0.07,alpha:1), NSColor(calibratedRed:0.02,green:0.16,blue:0.24,alpha:1)])!
bg.draw(in: NSRect(origin:.zero,size:size), angle: -45)
let ring = NSBezierPath(ovalIn: NSRect(x:150,y:150,width:724,height:724)); ring.lineWidth=34
NSColor(calibratedRed:0.10,green:0.68,blue:1,alpha:0.30).setStroke(); ring.stroke()
let mark = NSBezierPath(); mark.lineWidth=64; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
mark.move(to:NSPoint(x:230,y:430)); mark.line(to:NSPoint(x:390,y:590)); mark.line(to:NSPoint(x:515,y:465)); mark.line(to:NSPoint(x:690,y:640)); mark.line(to:NSPoint(x:790,y:540))
NSColor(calibratedRed:0.16,green:0.72,blue:1,alpha:1).setStroke(); mark.stroke()
let arrow=NSBezierPath(); arrow.lineWidth=64; arrow.lineCapStyle = .round
arrow.move(to:NSPoint(x:790,y:540)); arrow.line(to:NSPoint(x:790,y:745)); arrow.move(to:NSPoint(x:790,y:745)); arrow.line(to:NSPoint(x:600,y:745)); arrow.stroke()
let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:150,weight:.black),.foregroundColor:NSColor.white]
NSAttributedString(string:"T4",attributes:attrs).draw(at:NSPoint(x:230,y:205))
image.unlockFocus()
guard let tiff=image.tiffRepresentation, let rep=NSBitmapImageRep(data:tiff), let png=rep.representation(using:.png,properties:[:]) else { fatalError("icon") }
try png.write(to: URL(fileURLWithPath:"T4Bot/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
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
