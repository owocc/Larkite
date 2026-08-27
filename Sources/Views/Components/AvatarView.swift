import SwiftUI

public struct AvatarView: View {
    let urlString: String?
    let name: String
    let size: CGFloat
    
    public init(urlString: String?, name: String, size: CGFloat = 36) {
        self.urlString = urlString
        self.name = name
        self.size = size
    }
    
    public var body: some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        fallbackAvatar
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
                .frame(width: size, height: size)
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
    
    private var fallbackAvatar: some View {
        let initial = name.prefix(1).uppercased()
        let gradient = nameColorGradient(name: name)
        
        return ZStack {
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(initial.isEmpty ? "飞" : String(initial))
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private func nameColorGradient(name: String) -> [Color] {
        let colors: [[Color]] = [
            [Color(hex: "3370FF"), Color(hex: "295ECC")], // Blue
            [Color(hex: "00B67A"), Color(hex: "009A67")], // Green
            [Color(hex: "FF9C00"), Color(hex: "E68800")], // Orange
            [Color(hex: "7838FF"), Color(hex: "6124E6")], // Purple
            [Color(hex: "F54A45"), Color(hex: "D9363B")], // Red
            [Color(hex: "14C9C9"), Color(hex: "0EA5A5")]  // Cyan
        ]
        
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}
