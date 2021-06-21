import Foundation

public enum ChromeCookiesSameSitePolicy: String {
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

public protocol EditThisCookieConvertible {
    init(from cookieJar: EditThisCookie)
}

public protocol EditThisCookieExportable {
    func toEditThisCookie() -> EditThisCookie
}

public typealias EditThisCookie = [EditThisCookieItem]

extension EditThisCookie: MiddleCookieJarExportable {
    
    public func toMiddleCookieJar() -> MiddleCookieJar {
        return compactMap({ $0.toMiddleCookie() })
    }
    
}

public protocol EditThisCookieItemConvertible {
    init(from cookie: EditThisCookieItem)
}

public class EditThisCookieItem: Codable, CookieConvertible, HTTPCookieExportable, MiddleCookieExportable {
    
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
    
    public required init(from cookie: EditThisCookieItem) {
        domain = cookie.domain
        expirationDate = cookie.expirationDate
        httpOnly = cookie.httpOnly
        name = cookie.name
        path = cookie.path
        sameSite = cookie.sameSite
        secure = cookie.secure
        storeId = cookie.storeId
        value = cookie.value
        id = cookie.id
    }
    
    public required init(from cookie: BinaryCookie) {
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
    
    public required init(from cookie: NetscapeCookie) {
        domain = cookie.domain
        expirationDate = cookie.expiration
        httpOnly = cookie.isHTTPOnly
        name = cookie.name
        path = cookie.path
        sameSite = .unspecified
        secure = cookie.isSecure
        storeId = "0"
        value = cookie.value
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: LWPCookie) {
        domain = cookie.domain
        expirationDate = cookie.expires
        httpOnly = false
        name = cookie.key
        path = cookie.path ?? "/"
        sameSite = .unspecified
        secure = cookie.secure
        storeId = "0"
        value = cookie.val
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: HTTPCookie) {
        domain = cookie.domain
        expirationDate = cookie.expiresDate
        httpOnly = cookie.isHTTPOnly
        name = cookie.name
        path = cookie.path
        if #available(macOS 10.15, *) {
            switch cookie.sameSitePolicy {
                case HTTPCookieStringPolicy.sameSiteLax:
                    sameSite = .lax
                case HTTPCookieStringPolicy.sameSiteStrict:
                    sameSite = .strict
                default:
                    sameSite = .unspecified
            }
        } else {
            // Fallback on earlier versions
            sameSite = .unspecified
        }
        secure = cookie.isSecure
        storeId = "0"
        value = cookie.value
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: MiddleCookie) {
        self.domain = cookie[.domain] as! String
        if let expirationDate = cookie[.expires] as? Date {
            self.expirationDate = expirationDate
        } else if let expirationDate = cookie[.expires] as? String, let expInterval = TimeInterval(expirationDate) {
            self.expirationDate = Date(timeIntervalSince1970: expInterval)
        } else {
            self.expirationDate = Date.distantFuture
        }
        if let httpOnly = cookie[.httpOnly] as? Bool {
            self.httpOnly = httpOnly
        } else if let httpOnly = cookie[.httpOnly] as? String {
            self.httpOnly = Bool(httpOnly) ?? false
        } else {
            self.httpOnly = false
        }
        self.name = cookie[.name] as! String
        self.path = (cookie[.path] as? String) ?? "/"
        if let sameSite = cookie[.sameSitePolicy] as? HTTPCookieStringPolicy {
            switch sameSite {
                case HTTPCookieStringPolicy.sameSiteLax:
                    self.sameSite = .lax
                case HTTPCookieStringPolicy.sameSiteStrict:
                    self.sameSite = .strict
                default:
                    self.sameSite = .unspecified
            }
        } else {
            self.sameSite = .unspecified
        }
        if let secure = cookie[.secure] as? Bool {
            self.secure = secure
        } else if let secure = cookie[.secure] as? String {
            self.secure = Bool(secure) ?? false
        } else {
            self.secure = false
        }
        storeId = "0"
        value = cookie[.value] as! String
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public func toHTTPCookie() -> HTTPCookie? {
        return HTTPCookie(properties: toMiddleCookie()!)
    }
    
    public func toMiddleCookie() -> MiddleCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .name: name,
            .path: path,
            .secure: String(describing: secure),
            .value: value,
            .version: "0",
        ]
        if expirationDate != nil {
            props[.expires] = expirationDate!
        }
        switch sameSite {
            case .lax:
                props[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteLax.rawValue
            case .strict:
                props[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteStrict.rawValue
            default:
                break
        }
        return props
    }
    
    public required init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
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
