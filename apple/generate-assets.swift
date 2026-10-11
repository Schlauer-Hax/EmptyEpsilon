// Package the existing artwork at Apple's required sizes; run by CMake on macOS.
import AppKit

let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let catalog = URL(fileURLWithPath: CommandLine.arguments[2])
let tv = CommandLine.arguments[3] == "tvOS"
let metadata: [String: Any] = ["author": "EmptyEpsilon", "version": 1]

func contents(_ directory: URL, _ values: [String: Any]) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = values
    values["info"] = metadata
    try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("Contents.json"))
}

func png(_ path: URL, width: Int, height: Int, artwork: String?, opaque: Bool) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current!.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)
    (opaque ? NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.06, alpha: 1) : .clear).setFill()
    bounds.fill()
    if let artwork = artwork {
        let source = NSImage(contentsOf: resources.appendingPathComponent(artwork))!
        let scale = min(CGFloat(width) * 0.8 / source.size.width, CGFloat(height) * 0.8 / source.size.height)
        let size = NSSize(width: source.size.width * scale, height: source.size.height * scale)
        source.draw(in: NSRect(x: (CGFloat(width) - size.width) / 2,
                              y: (CGFloat(height) - size.height) / 2,
                              width: size.width, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: path)
}

try contents(catalog, [:])
if !tv {
    let icon = catalog.appendingPathComponent("AppIcon.appiconset")
    try contents(icon, ["images": [["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon.png"]]])
    try png(icon.appendingPathComponent("icon.png"), width: 1024, height: 1024, artwork: "logo_icon.png", opaque: true)
} else {
    let brand = catalog.appendingPathComponent("AppIcon.brandassets")
    try contents(brand, ["assets": [
        ["idiom": "tv", "size": "400x240", "role": "primary-app-icon", "filename": "Small.imagestack"],
        ["idiom": "tv", "size": "1280x768", "role": "primary-app-icon", "filename": "Large.imagestack"],
        ["idiom": "tv", "size": "1920x720", "role": "top-shelf-image", "filename": "TopShelf.imageset"],
        ["idiom": "tv", "size": "2320x720", "role": "top-shelf-image-wide", "filename": "TopShelfWide.imageset"]
    ]])
    for (name, width, height, scales) in [("Small", 400, 240, [1, 2]), ("Large", 1280, 768, [1])] {
        let stack = brand.appendingPathComponent("\(name).imagestack")
        try contents(stack, ["layers": [["filename": "Foreground.imagestacklayer"], ["filename": "Background.imagestacklayer"]]])
        for layer in ["Foreground", "Background"] {
            let directory = stack.appendingPathComponent("\(layer).imagestacklayer")
            try contents(directory, [:])
            let images = directory.appendingPathComponent("Content.imageset")
            try contents(images, ["images": scales.map { ["idiom": "tv", "scale": "\($0)x", "filename": "\($0)x.png"] }])
            for scale in scales {
                try png(images.appendingPathComponent("\(scale)x.png"), width: width * scale, height: height * scale,
                    artwork: layer == "Foreground" ? "logo_icon.png" : nil, opaque: layer == "Background")
            }
        }
    }
    for (name, width) in [("TopShelf", 1920), ("TopShelfWide", 2320)] {
        let images = brand.appendingPathComponent("\(name).imageset")
        try contents(images, ["images": [1, 2].map { ["idiom": "tv", "scale": "\($0)x", "filename": "\($0)x.png"] }])
        for scale in [1, 2] {
            try png(images.appendingPathComponent("\(scale)x.png"), width: width * scale, height: 720 * scale,
                artwork: "logo_full.png", opaque: true)
        }
    }
}
