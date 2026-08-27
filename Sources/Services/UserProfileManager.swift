import Foundation
import AppKit

/// Cached profile for any Feishu user / contact / bot
public struct CachedUserProfile: Codable, Equatable, Hashable, Sendable {
    public let openId: String
    public let name: String
    public let avatarUrl: String?
    public let email: String?
    public let jobTitle: String?
    
    public init(
        openId: String,
        name: String,
        avatarUrl: String? = nil,
        email: String? = nil,
        jobTitle: String? = nil
    ) {
        self.openId = openId
        self.name = name
        self.avatarUrl = avatarUrl
        self.email = email
        self.jobTitle = jobTitle
    }
}

/// Unified User Profile Resolution & Cache Manager
@MainActor
public final class UserProfileManager: ObservableObject {
    public static let shared = UserProfileManager()
    
    @Published private(set) var profiles: [String: CachedUserProfile] = [:]
    private var inFlightQueries = Set<String>()
    
    private init() {}
    
    /// Registers or updates a known user profile
    public func registerUser(
        openId: String,
        name: String,
        avatarUrl: String? = nil,
        email: String? = nil,
        jobTitle: String? = nil
    ) {
        guard !openId.isEmpty else { return }
        let profile = CachedUserProfile(
            openId: openId,
            name: name,
            avatarUrl: avatarUrl,
            email: email,
            jobTitle: jobTitle
        )
        profiles[openId] = profile
    }
    
    /// Seeds cache with contacts and logged-in user
    public func seedWith(user: FeishuUserInfo?, contacts: [FeishuContactUser]) {
        if let current = user, let openId = current.openId {
            registerUser(
                openId: openId,
                name: current.displayName,
                avatarUrl: current.bestAvatarUrl,
                email: current.email
            )
        }
        
        for contact in contacts {
            if let openId = contact.openId {
                registerUser(
                    openId: openId,
                    name: contact.displayName,
                    avatarUrl: contact.bestAvatarUrl,
                    email: contact.email,
                    jobTitle: contact.jobTitle
                )
            }
        }
    }
    
    /// Seeds cache from chat members
    public func seedWithMembers(_ members: [FeishuChatMemberItem]) {
        for member in members {
            if !member.memberId.isEmpty {
                registerUser(
                    openId: member.memberId,
                    name: member.displayName
                )
            }
        }
    }
    
    /// Seeds cache from message mentions
    public func seedWithMentions(_ mentions: [MessageMention]) {
        for mention in mentions {
            if !mention.id.isEmpty, let name = mention.name, !name.isEmpty {
                registerUser(openId: mention.id, name: name)
            }
        }
    }
    
    /// Returns cached user profile if present
    public func getProfile(for openId: String) -> CachedUserProfile? {
        profiles[openId]
    }
    
    /// Resolves display name for an openId
    public func resolveDisplayName(for openId: String, currentUserId: String?) -> String {
        if let current = currentUserId, openId == current {
            return profiles[openId]?.name ?? "我"
        }
        if let profile = profiles[openId] {
            return profile.name
        }
        return "用户 (\(openId.prefix(6)))"
    }
    
    /// Resolves avatar URL for an openId
    public func resolveAvatarUrl(for openId: String) -> String? {
        profiles[openId]?.avatarUrl
    }
}
