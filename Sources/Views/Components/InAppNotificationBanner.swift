import SwiftUI
import AppKit

public struct InAppNotificationBanner: View {
    let notification: AppInAppNotification
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init(notification: AppInAppNotification) {
        self.notification = notification
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Type Icon
            iconView
                .font(.system(size: 18))
                .padding(.top, 2)
            
            // Content Info
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Dismiss Button
            Button {
                appState.dismissNotification()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .help("清除提醒")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 420)
        .background(
            Color.elevatedInputBackground
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 6)
        .padding(.top, 14)
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch notification.type {
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(hex: "3370FF"))
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
    
    private var strokeColor: Color {
        switch notification.type {
        case .error:
            return Color.red.opacity(0.25)
        case .warning:
            return Color.orange.opacity(0.25)
        default:
            return Color(nsColor: .separatorColor).opacity(0.4)
        }
    }
}
