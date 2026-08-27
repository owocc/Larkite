import SwiftUI
import AppKit

/// Native AppKit NSTextView wrapper that supports multi-line auto-expansion and Cmd+V paste for Images & Files
public struct PasteableMessageField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isExpanded: Bool
    @Binding var contentHeight: CGFloat
    var onCommit: () -> Void
    var onPasteImage: (Data, String) -> Void
    var onPasteFile: (Data, String) -> Void
    
    public init(
        text: Binding<String>,
        placeholder: String = "输入消息 (Enter 发送, Shift+Enter 换行)...",
        isExpanded: Bool = false,
        contentHeight: Binding<CGFloat> = .constant(24),
        onCommit: @escaping () -> Void,
        onPasteImage: @escaping (Data, String) -> Void,
        onPasteFile: @escaping (Data, String) -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isExpanded = isExpanded
        self._contentHeight = contentHeight
        self.onCommit = onCommit
        self.onPasteImage = onPasteImage
        self.onPasteFile = onPasteFile
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = CustomPasteNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isSelectable = true
        textView.isEditable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.focusRingType = .none
        textView.placeholderString = placeholder
        
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        
        textView.onPasteImage = onPasteImage
        textView.onPasteFile = onPasteFile
        textView.onCommit = onCommit
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomPasteNSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
            context.coordinator.recalculateHeight(for: textView)
        }
        textView.placeholderString = placeholder
        textView.onPasteImage = onPasteImage
        textView.onPasteFile = onPasteFile
        textView.onCommit = onCommit
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PasteableMessageField
        weak var textView: CustomPasteNSTextView?
        
        init(_ parent: PasteableMessageField) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            recalculateHeight(for: tv)
        }
        
        func recalculateHeight(for tv: NSTextView) {
            guard let layoutManager = tv.layoutManager, let textContainer = tv.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let calculatedHeight = max(24, usedRect.height + 8)
            if abs(parent.contentHeight - calculatedHeight) > 1 {
                DispatchQueue.main.async {
                    self.parent.contentHeight = calculatedHeight
                }
            }
        }
    }
}

/// Custom NSTextView subclass overriding pasteboard actions and Cmd+V
public final class CustomPasteNSTextView: NSTextView {
    var onPasteImage: ((Data, String) -> Void)?
    var onPasteFile: ((Data, String) -> Void)?
    var onCommit: (() -> Void)?
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholderString.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let rect = NSRect(x: 5, y: 4, width: bounds.width - 10, height: bounds.height - 8)
            (placeholderString as NSString).draw(in: rect, withAttributes: attrs)
        }
    }
    
    public override func keyDown(with event: NSEvent) {
        // Return key without Shift/Option -> Send message
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.option) {
            onCommit?()
            return
        }
        
        // Shift+Return or Option+Return -> Insert newline
        if event.keyCode == 36 && (event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option)) {
            insertNewlineIgnoringFieldEditor(nil)
            return
        }
        
        super.keyDown(with: event)
    }
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept Cmd+V (Paste) for image/file pasteboard data
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
