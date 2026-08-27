import SwiftUI
import AppKit

/// Native AppKit NSTextField wrapper that intercepts Cmd+V paste for Images and Files
public struct PasteableMessageField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var onPasteImage: (Data, String) -> Void
    var onPasteFile: (Data, String) -> Void
    
    public init(
        text: Binding<String>,
        placeholder: String = "发送消息...",
        onCommit: @escaping () -> Void,
        onPasteImage: @escaping (Data, String) -> Void,
        onPasteFile: @escaping (Data, String) -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
        self.onPasteImage = onPasteImage
        self.onPasteFile = onPasteFile
    }
    
    public func makeNSView(context: Context) -> CustomPasteNSTextField {
        let textField = CustomPasteNSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.textColor = NSColor.labelColor
        
        textField.onPasteImage = onPasteImage
        textField.onPasteFile = onPasteFile
        textField.onCommit = onCommit
        
        return textField
    }
    
    public func updateNSView(_ nsView: CustomPasteNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.onPasteImage = onPasteImage
        nsView.onPasteFile = onPasteFile
        nsView.onCommit = onCommit
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PasteableMessageField
        
        init(_ parent: PasteableMessageField) {
            self.parent = parent
        }
        
        public func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

/// Custom NSTextField subclass overriding pasteboard actions and Cmd+V
public final class CustomPasteNSTextField: NSTextField {
    var onPasteImage: ((Data, String) -> Void)?
    var onPasteFile: ((Data, String) -> Void)?
    var onCommit: (() -> Void)?
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept Return key (without Shift) to send message
        if event.keyCode == 36 { // Return key
            if !event.modifierFlags.contains(.shift) {
                onCommit?()
                return true
            }
        }
        
        // Intercept Cmd+V (Paste)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            if handlePasteboard() {
                return true
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    private func handlePasteboard() -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 1. Check for Image Data (PNG / TIFF)
        if let pngData = pasteboard.data(forType: .png) {
            let timestamp = Int(Date().timeIntervalSince1970)
            onPasteImage?(pngData, "截屏_\(timestamp).png")
            return true
        }
        
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData),
           let tiffRep = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let timestamp = Int(Date().timeIntervalSince1970)
            onPasteImage?(pngData, "截屏_\(timestamp).png")
            return true
        }
        
        // 2. Check for File URLs copied in Finder (Cmd+C)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstUrl = urls.first {
            let ext = firstUrl.pathExtension.lowercased()
            if let fileData = try? Data(contentsOf: firstUrl) {
                if ["png", "jpg", "jpeg", "webp", "gif", "bmp", "heic", "tiff"].contains(ext) {
                    onPasteImage?(fileData, firstUrl.lastPathComponent)
                } else {
                    onPasteFile?(fileData, firstUrl.lastPathComponent)
                }
                return true
            }
        }
        
        // 3. Fallback to normal text pasting
        return false
    }
}
