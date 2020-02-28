import Foundation

enum ChromeCookiesSameSitePolicy: String {
    case unspecified
    case no_restriction
    case lax
    case strict
}

public enum EditThisCookieError: Error {
    case inconsistentStateOfHostOnly
    case inconsistentStateOfSession
    case invalidValueOfSameSite
}

typealias EditThisCookie = [EditThisCookieItem]

extension Array where Element == EditThisCookieItem {
    
    init(from cookies: BinaryCookies) {
        self.init()
        append(contentsOf: cookies.pages
            .flatMap({ $0.cookies })
            .map({ EditThisCookieItem(from: $0) }))
    }
    
}

class EditThisCookieItem: Codable {
    public var domain: String
    public var expirationDate: Date?
    public var hostOnly: Bool {
        return !domain.hasPrefix(".")
    }
    public var httpOnly: Bool = false
    public var name: String
    public var path: String
    public var sameSite: ChromeCookiesSameSitePolicy = .unspecified
    public var secure: Bool = false
    public var session: Bool {
        return expirationDate == nil
    }
    public var storeId: String
    public var value: String
    public var id: Int
    public static var autoIncrement: Int = 1
    
    enum CodingKeys: String, CodingKey {
        case domain, expirationDate, hostOnly, httpOnly, name, path, sameSite, secure, session, storeId, value, id
    }
    
    init(from cookie: BinaryCookie) {
        domain = cookie.url
        expirationDate = cookie.expiration
        httpOnly = cookie.flags.contains(.isHTTPOnly)
        name = cookie.name
        path = cookie.path
        sameSite = .unspecified
        secure = cookie.flags.contains(.isSecure)
        storeId = "0"
        value = cookie.value
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let domain = try container.decode(String.self, forKey: .domain)
        var expirationDate: Date?
        if let expiration = try container.decodeIfPresent(TimeInterval.self, forKey: .expirationDate) {
            expirationDate = Date(timeIntervalSince1970: expiration)
        }
        let hostOnly = try container.decode(Bool.self, forKey: .hostOnly)
        guard hostOnly || domain.hasPrefix(".") else {
            throw EditThisCookieError.inconsistentStateOfHostOnly
        }
        self.domain = domain
        httpOnly = try container.decode(Bool.self, forKey: .httpOnly)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        guard let sameSite = ChromeCookiesSameSitePolicy(rawValue: try container.decode(String.self, forKey: .sameSite)) else {
            throw EditThisCookieError.invalidValueOfSameSite
        }
        self.sameSite = sameSite
        secure = try container.decode(Bool.self, forKey: .secure)
        let session = try container.decode(Bool.self, forKey: .session)
        guard session || expirationDate != nil else {
            throw EditThisCookieError.inconsistentStateOfSession
        }
        self.expirationDate = expirationDate
        storeId = try container.decode(String.self, forKey: .storeId)
        value = try container.decode(String.self, forKey: .value)
        id = try container.decode(Int.self, forKey: .id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(domain, forKey: .domain)
        if let expirationDate = expirationDate {
            try container.encode(expirationDate.timeIntervalSince1970, forKey: .expirationDate)
        }
        try container.encode(hostOnly, forKey: .hostOnly)
        try container.encode(httpOnly, forKey: .httpOnly)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(sameSite.rawValue, forKey: .sameSite)
        try container.encode(secure, forKey: .secure)
        try container.encode(session, forKey: .session)
        try container.encode(storeId, forKey: .storeId)
        try container.encode(value, forKey: .value)
        try container.encode(id, forKey: .id)
    }
}
