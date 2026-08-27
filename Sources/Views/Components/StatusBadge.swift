import SwiftUI

public struct StatusBadge: View {
    let title: String
    let color: Color
    let icon: String?
    
    public init(_ title: String, color: Color = Color(hex: "3370FF"), icon: String? = nil) {
        self.title = title
        self.color = color
        self.icon = icon
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .foregroundColor(color)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
