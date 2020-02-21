import Foundation
import BinaryCodable

public enum NetscapeCookiesError: Error {
    case lineShouldSkip
    case lineSkipped
}

class NetscapeCookies: BinaryCodable, Codable {
    public var cookies: [NetscapeCookie]
    
    enum CodingKeys: String, CodingKey {
        case cookies
    }
    
    init(from cookies: BinaryCookies) {
        self.cookies = cookies.pages.flatMap({ $0.cookies })
            .map({ NetscapeCookie(from: $0) })
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cookies = try container.decode([NetscapeCookie].self, forKey: .cookies)
    }
    
    required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        var cookies: [NetscapeCookie] = []
        while !container.isAtEnd {
            do {
                if NetscapeCookies.skippedPrefixes.contains(Unicode.Scalar(try container.peek(length: 1).first!)) {
                    throw NetscapeCookiesError.lineShouldSkip
                }
                var cookieContainer = container.nestedContainer(maxLength: nil)
                let cookie = try cookieContainer.decode(NetscapeCookie.self)
                cookies.append(cookie)
            } catch NetscapeCookiesError.lineShouldSkip {
                _ = try? container.decodeString(encoding: .utf8, terminator: NetscapeCookies.newlineCharacter)
                continue
            } catch NetscapeCookiesError.lineSkipped {
                continue
            }
        }
        
        if cookies.count == 0 {
            throw BinaryDecodingError.dataCorrupted(.init(debugDescription: "cookie not found"))
        }
        
        self.cookies = cookies
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cookies, forKey: .cookies)
    }
    
    func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        try container.encode(sequence: NetscapeCookies.optionalHeader)
        try container.encode(cookies)
    }
    
    private static let optionalHeader = Data("""
# Netscape HTTP Cookie File
# https://curl.haxx.se/docs/http-cookies.html
# This file was generated by libcurl! Edit at your own risk.


""".utf8)
    private static let skippedPrefixes = CharacterSet.whitespacesAndNewlines
    private static let newlineCharacter = "\n".utf8.first!
}

class NetscapeCookie: BinaryCodable, Codable {
    public var isHTTPOnly: Bool = false
    public var domain: String!
    public var includeSubdomains: Bool = false
    public var path: String!
    public var isSecure: Bool = false
    public let expiration: Date
    public var name: String!
    public var value: String!
    
    enum CodingKeys: String, CodingKey {
        case isHTTPOnly, domain, includeSubdomains, path, isSecure, expiration, name, value
    }
    
    init(from cookie: BinaryCookie) {
        isHTTPOnly = cookie.flags.contains(.isHTTPOnly)
        domain = cookie.url
        includeSubdomains = cookie.url.hasPrefix(".")
        path = cookie.path
        isSecure = cookie.flags.contains(.isSecure)
        expiration = cookie.expiration
        name = cookie.name
        value = cookie.value
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        isHTTPOnly = try container.decode(Bool.self, forKey: .isHTTPOnly)
        domain = try container.decode(String.self, forKey: .domain)
        includeSubdomains = try container.decode(Bool.self, forKey: .includeSubdomains)
        path = try container.decode(String.self, forKey: .path)
        isSecure = try container.decode(Bool.self, forKey: .isSecure)
        expiration = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .expiration))
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)
    }
    
    required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        let prefixData = try container.peek(length: NetscapeCookie.httpOnlyPrefix.count)
        if prefixData == NetscapeCookie.httpOnlyPrefix {
            _ = try? container.decode(length: prefixData.count)
            isHTTPOnly = true
        }
        else if prefixData.first == NetscapeCookie.skipPrefix.first {
            _ = try? container.decodeString(encoding: .utf8, terminator: NetscapeCookie.newlineCharacter)
            throw NetscapeCookiesError.lineSkipped
        }
        
        domain = try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        includeSubdomains = (try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.tabCharacter).uppercased() == "TRUE")
        path = try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        isSecure = (try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.tabCharacter).uppercased() == "TRUE")
        expiration = Date(timeIntervalSince1970: TimeInterval(try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.tabCharacter)) ?? 0.0)
        name = try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        value = try container.decodeString(encoding: .utf8, terminator: NetscapeCookie.newlineCharacter)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(isHTTPOnly, forKey: .isHTTPOnly)
        try container.encode(domain, forKey: .domain)
        try container.encode(includeSubdomains, forKey: .includeSubdomains)
        try container.encode(path, forKey: .path)
        try container.encode(isSecure, forKey: .isSecure)
        try container.encode(expiration.timeIntervalSince1970, forKey: .expiration)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
    }
    
    func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        if isHTTPOnly {
            try container.encode(sequence: NetscapeCookie.httpOnlyPrefix)
        }
        try container.encode(domain, encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        try container.encode(includeSubdomains ? "TRUE" : "FALSE", encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        try container.encode(path, encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        try container.encode(isSecure ? "TRUE" : "FALSE", encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        try container.encode(String(Int(expiration.timeIntervalSince1970)), encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        try container.encode(name, encoding: .utf8, terminator: NetscapeCookie.tabCharacter)
        try container.encode(value, encoding: .utf8, terminator: NetscapeCookie.newlineCharacter)
    }
    
    private static let tabCharacter = "\t".utf8.first!
    private static let newlineCharacter = "\n".utf8.first!
    private static let skipPrefix = Data("#".utf8)
    private static let httpOnlyPrefix = Data("#HttpOnly_".utf8)
}