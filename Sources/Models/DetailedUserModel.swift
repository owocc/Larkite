import Foundation

/// Detailed User Profile Response from contact/v3/users/:user_id
public struct FeishuUserDetailResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuUserDetailData?
}

public struct FeishuUserDetailData: Codable, Sendable {
    public let user: DetailedFeishuUser?
}

public struct DetailedDepartmentPath: Codable, Equatable, Hashable, Sendable {
    public let departmentId: String?
    public let departmentName: DetailedDepartmentName?
    
    enum CodingKeys: String, CodingKey {
        case departmentId = "department_id"
        case departmentName = "department_name"
    }
}

public struct DetailedDepartmentName: Codable, Equatable, Hashable, Sendable {
    public let name: String?
    public let zhCn: String?
    public let enUs: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case zhCn = "zh_cn"
        case enUs = "en_us"
    }
}

public struct DetailedUserStatus: Codable, Equatable, Hashable, Sendable {
    public let isFrozen: Bool?
    public let isResigned: Bool?
    public let isActivated: Bool?
    public let isExited: Bool?
    public let isUnjoin: Bool?
    
    public var description: String {
        if isResigned == true { return "已离职" }
        if isFrozen == true { return "已冻结" }
        if isActivated == true { return "正常在职" }
        if isUnjoin == true { return "未加入" }
        return "正常"
    }
    
    enum CodingKeys: String, CodingKey {
        case isFrozen = "is_frozen"
        case isResigned = "is_resigned"
        case isActivated = "is_activated"
        case isExited = "is_exited"
        case isUnjoin = "is_unjoin"
    }
}

/// Full Feishu User Profile with all fields
public struct DetailedFeishuUser: Codable, Identifiable, Equatable, Sendable {
    public var id: String { openId ?? userId ?? unionId ?? UUID().uuidString }
    
    public let openId: String?
    public let userId: String?
    public let unionId: String?
    public let name: String?
    public let enName: String?
    public let nickname: String?
    public let email: String?
    public let enterpriseEmail: String?
    public let mobile: String?
    public let mobileVisible: Bool?
    public let gender: Int?
    public let avatar: FeishuContactAvatar?
    public let status: DetailedUserStatus?
    public let departmentIds: [String]?
    public let leaderUserId: String?
    public let city: String?
    public let country: String?
    public let workStation: String?
    public let joinTime: Int?
    public let isTenantManager: Bool?
    public let employeeNo: String?
    public let employeeType: Int?
    public let jobTitle: String?
    public let geo: String?
    public let jobLevelId: String?
    public let jobFamilyId: String?
    public let departmentPath: [DetailedDepartmentPath]?
    public var rawJsonString: String?
    
    public var displayName: String {
        if let nickname = nickname, !nickname.isEmpty { return "\(name ?? "") (\(nickname))" }
        if let name = name, !name.isEmpty { return name }
        if let enName = enName, !enName.isEmpty { return enName }
        return "用户 (\(id.prefix(6)))"
    }
    
    public var bestAvatarUrl: String? {
        avatar?.bestUrl
    }
    
    public var genderDescription: String {
        switch gender {
        case 1: return "男 ♂"
        case 2: return "女 ♀"
        default: return "未设置"
        }
    }
    
    public var employeeTypeDescription: String {
        switch employeeType {
        case 1: return "正式员工"
        case 2: return "实习生"
        case 3: return "外包员工"
        case 4: return "劳务人员"
        case 5: return "顾问"
        default: return "员工"
        }
    }
    
    public var formattedJoinTime: String? {
        guard let jt = joinTime, jt > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(jt))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    public var departmentSummary: String? {
        if let paths = departmentPath, !paths.isEmpty {
            let names = paths.compactMap { $0.departmentName?.name ?? $0.departmentName?.zhCn }
            if !names.isEmpty {
                return names.joined(separator: " / ")
            }
        }
        if let ids = departmentIds, !ids.isEmpty {
            return "部门 (\(ids.count) 个)"
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case openId = "open_id"
        case userId = "user_id"
        case unionId = "union_id"
        case name
        case enName = "en_name"
        case nickname
        case email
        case enterpriseEmail = "enterprise_email"
        case mobile
        case mobileVisible = "mobile_visible"
        case gender
        case avatar
        case status
        case departmentIds = "department_ids"
        case leaderUserId = "leader_user_id"
        case city
        case country
        case workStation = "work_station"
        case joinTime = "join_time"
        case isTenantManager = "is_tenant_manager"
        case employeeNo = "employee_no"
        case employeeType = "employee_type"
        case jobTitle = "job_title"
        case geo
        case jobLevelId = "job_level_id"
        case jobFamilyId = "job_family_id"
        case departmentPath = "department_path"
    }
}
