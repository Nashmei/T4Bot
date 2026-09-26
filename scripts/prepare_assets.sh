#!/bin/bash
set -euo pipefail

ICON_DIR="T4Bot/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICON_DIR"

cat > "$RUNNER_TEMP/t4bot_icon.swift" <<'SWIFT'
import AppKit
let size=NSSize(width:1024,height:1024), image=NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
NSGradient(colors:[NSColor(calibratedRed:0.10,green:0.36,blue:0.92,alpha:1),NSColor(calibratedRed:0.20,green:0.66,blue:0.94,alpha:1)])!.draw(in:NSRect(origin:.zero,size:size),angle:-35)
let base=NSBezierPath(ovalIn:NSRect(x:180,y:180,width:664,height:664)); base.lineWidth=72
NSColor.white.withAlphaComponent(0.16).setStroke(); base.stroke()
let arc=NSBezierPath(); arc.lineWidth=72; arc.lineCapStyle=.round
arc.appendArc(withCenter:NSPoint(x:512,y:512),radius:332,startAngle:-50,endAngle:225)
NSColor(calibratedRed:0.78,green:0.98,blue:0.30,alpha:1).setStroke(); arc.stroke()
let bolt=NSBezierPath(); bolt.move(to:NSPoint(x:555,y:280)); bolt.line(to:NSPoint(x:395,y:535)); bolt.line(to:NSPoint(x:500,y:535)); bolt.line(to:NSPoint(x:450,y:735)); bolt.line(to:NSPoint(x:635,y:460)); bolt.line(to:NSPoint(x:525,y:460)); bolt.close()
NSColor.white.setFill(); bolt.fill()
image.unlockFocus()
guard let t=image.tiffRepresentation,let r=NSBitmapImageRep(data:t),let d=r.representation(using:.png,properties:[:]) else{fatalError()}
try d.write(to:URL(fileURLWithPath:"T4Bot/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
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
