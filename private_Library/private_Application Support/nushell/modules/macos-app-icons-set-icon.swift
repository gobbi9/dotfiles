import AppKit
import Foundation

let args = CommandLine.arguments
if args.count < 3 {
    fputs("usage: macos-app-icons-set-icon.swift <app_bundle> <icon_path>\n", stderr)
    exit(2)
}

let appPath = args[1]
let iconPath = args[2]

guard let icon = NSImage(contentsOfFile: iconPath) else {
    fputs("failed to load icon image at \(iconPath)\n", stderr)
    exit(3)
}

let ok = NSWorkspace.shared.setIcon(icon, forFile: appPath, options: [])
if !ok {
    fputs("NSWorkspace.setIcon failed for \(appPath)\n", stderr)
    exit(4)
}
