import SwiftUI
import AppKit

// MARK: - Visual Effect View Wrapper (macOS Native Vibrancy)

public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Liquid Glass Theme & Palettes

public struct LiquidGlassTheme {
    public static let primaryGradient = LinearGradient(
        colors: [Color(hex: "3370FF"), Color(hex: "1F55E6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let specularRimLight = LinearGradient(
        colors: [
            Color.white.opacity(0.32),
            Color.white.opacity(0.12),
            Color.white.opacity(0.04),
            Color.white.opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let pillDarkSurface = LinearGradient(
        colors: [
            Color.black.opacity(0.45),
            Color.black.opacity(0.35)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Liquid Glass Capsule Container

public struct LiquidGlassPill<Content: View>: View {
    private let content: Content
    private var paddingHorizontal: CGFloat
    private var paddingVertical: CGFloat

    public init(
        paddingHorizontal: CGFloat = 12,
        paddingVertical: CGFloat = 6,
        @ViewBuilder content: () -> Content
    ) {
        self.paddingHorizontal = paddingHorizontal
        self.paddingVertical = paddingVertical
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, paddingHorizontal)
            .padding(.vertical, paddingVertical)
            .background(
                ZStack {
                    VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                    Color(nsColor: .controlBackgroundColor).opacity(0.55)
                }
                .clipShape(Capsule())
            )
            .overlay(
                Capsule()
                    .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Liquid Glass Toolbar Action Button

@MainActor
public final class LiquidToolbarButtonViewModel: ObservableObject {
    @Published public var isHovered: Bool = false
    public init() {}
}

public struct LiquidGlassToolbarButton: View {
    let icon: String?
    let title: String?
    let hasDropdown: Bool
    let isActive: Bool
    let action: () -> Void
    
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = LiquidToolbarButtonViewModel()
    
    public init(
        icon: String? = nil,
        title: String? = nil,
        hasDropdown: Bool = false,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.hasDropdown = hasDropdown
        self.isActive = isActive
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                
                if let title = title {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                
                if hasDropdown {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.7)
                }
            }
            .foregroundColor(isActive ? configManager.accentColorChoice.color : (viewModel.isHovered ? .primary : .secondary))
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(viewModel.isHovered ? Color.white.opacity(0.12) : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.isHovered = hovering
            }
        }
    }
}

// MARK: - Liquid Glass Send Pill Button

@MainActor
public final class LiquidSendButtonViewModel: ObservableObject {
    @Published public var isHovered: Bool = false
    public init() {}
}

public struct LiquidGlassSendButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = LiquidSendButtonViewModel()
    
    public init(
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(
                        isDisabled ?
                        LinearGradient(colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [configManager.accentColorChoice.color, configManager.accentColorChoice.color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(isDisabled ? 0.1 : 0.35), lineWidth: 1)
            )
            .shadow(color: isDisabled ? Color.clear : configManager.accentColorChoice.color.opacity(0.4), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.isHovered = hovering
            }
        }
    }
}
