import Foundation
import BinaryCodable


func usage() {
    print("""
Usage: CookiesTool [OPTIONS]... [FILE]...
Convert between Apple BinaryCookies, EditThisCookie and Netscape HTTP Cookie File.

Command options are (-l is the default):
  -h | --help               show this message and exit
  -l | --lint               check the cookies file for syntax errors
  -c | --convert FORMAT     rewrite cookies file in format
  -o | --output PATH        specify file path name for result;
                            the -o option is used with -c, and is only useful
                            with one file argument;
  -r | --readable           if writing JSON, output in human-readable form

FORMAT is one of: binarycookies plist xml json edit-this-cookie netscape
""")
}


enum CustomError: LocalizedError {
    case invalidOption
    case invalidArgumentFormat
    case missingArgumentFile
    case missingOptionOutput
    case missingArgumentConvert
    case missingArgumentOutput
    case invalidFileFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidOption:
            return "invalid option"
        case .invalidArgumentFormat:
            return "invalid argument: FORMAT"
        case .missingArgumentFile:
            return "missing argument: FILE"
        case .missingOptionOutput:
            return "missing required option: --output"
        case .missingArgumentConvert:
            return "missing argument for: --convert"
        case .missingArgumentOutput:
            return "missing argument for: --output"
        case .invalidFileFormat:
            return "invalid file format"
        }
    }
}


enum Mode {
    case help
    case lint
    case convert
}


enum Format: String {
    case invalid        = ""
    case binary         = "binarycookies"
    case plistBinary    = "plist"
    case plistXML       = "xml"
    case JSON           = "json"
    case editThisCookie = "edit-this-cookie"
    case netscape       = "netscape"
}


struct Options: OptionSet {
    let rawValue: Int
    static let jsonReadable = Options(rawValue: 1 << 0)
}


do {
    
    var mode = Mode.lint
    var inFormat = Format.invalid
    var outFormat = Format.binary
    var options: Options = []
    var outputPath: String? = nil
    var inputPaths: [String] = []
    
    
    // MARK: - Parse Arguments
    let args = CommandLine.arguments
    var i = 1
    while i < args.count {
        if args[i] == "-h" || args[i] == "--help" {
            mode = .help
            break
        }
        else if args[i] == "-l" || args[i] == "--lint" {
            mode = .lint
            break
        }
        else if args[i] == "-c" || args[i] == "--convert" {
            mode = .convert
            guard let argi = args[safe: i + 1] else {
                throw CustomError.missingArgumentConvert
            }
            guard let argiFormat = Format(rawValue: argi) else {
                throw CustomError.invalidArgumentFormat
            }
            outFormat = argiFormat
            i = i + 1
        }
        else if args[i] == "-r" || args[i] == "--readable" {
            options.insert(.jsonReadable)
        }
        else if args[i] == "-o" || args[i] == "--output" {
            mode = .convert
            guard let argiPath = args[safe: i + 1] else {
                throw CustomError.missingArgumentOutput
            }
            outputPath = argiPath
            i = i + 1
        }
        else {
            inputPaths.append(args[i])
        }
        
        i = i + 1
    }
    
    
    // MARK: - Help
    guard mode != .help else {
        usage()
        exit(EXIT_SUCCESS)
    }
    
    
    // MARK: - Lint (Read)
    guard let path = inputPaths.first else {
        throw CustomError.missingArgumentFile
    }
    let url = URL(fileURLWithPath: path, relativeTo: nil)
    let data = try Data(contentsOf: url)
    var rawCookies: Any?
    var binaryCookies: BinaryCookies
    if let tryDecodeCookies = try? BinaryDataDecoder().decode(BinaryCookies.self, from: data) {
        inFormat = .binary
        guard mode != .lint else {
            dump(tryDecodeCookies)
            exit(EXIT_SUCCESS)
        }
        binaryCookies = tryDecodeCookies
    }
    else if let tryDecodeCookies = try? PropertyListDecoder().decode(BinaryCookies.self, from: data) {
        inFormat = .plistBinary
        guard mode != .lint else {
            dump(tryDecodeCookies)
            exit(EXIT_SUCCESS)
        }
        binaryCookies = tryDecodeCookies
    }
    else if let tryDecodeCookies = try? JSONDecoder().decode(BinaryCookies.self, from: data) {
        inFormat = .JSON
        guard mode != .lint else {
            dump(tryDecodeCookies)
            exit(EXIT_SUCCESS)
        }
        binaryCookies = tryDecodeCookies
    }
    else if let tryDecodeCookies = try? JSONDecoder().decode(EditThisCookie.self, from: data) {
        inFormat = .editThisCookie
        guard mode != .lint else {
            dump(tryDecodeCookies)
            exit(EXIT_SUCCESS)
        }
        if outFormat == inFormat { rawCookies = tryDecodeCookies }
        binaryCookies = BinaryCookies(from: tryDecodeCookies)
    }
    else if let tryDecodeCookies = try? BinaryDataDecoder().decode(NetscapeCookies.self, from: data) {
        inFormat = .netscape
        guard mode != .lint else {
            dump(tryDecodeCookies)
            exit(EXIT_SUCCESS)
        }
        if outFormat == inFormat { rawCookies = tryDecodeCookies }
        binaryCookies = BinaryCookies(from: tryDecodeCookies)
    }
    else {
        throw CustomError.invalidFileFormat
    }
    
    
    // MARK: - Convert
    guard let toPath = outputPath else {
        throw CustomError.missingOptionOutput
    }
    let toURL = URL(fileURLWithPath: toPath, relativeTo: nil)
    var outputData: Data
    switch outFormat {
    case .binary:
        outputData = try BinaryDataEncoder().encode(binaryCookies)
    case .plistBinary:
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        outputData = try encoder.encode(binaryCookies)
    case .plistXML:
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        outputData = try encoder.encode(binaryCookies)
    case .JSON:
        let encoder = JSONEncoder()
        encoder.outputFormatting = options.contains(.jsonReadable) ? [.prettyPrinted, .sortedKeys] : []
        outputData = try encoder.encode(binaryCookies)
    case .editThisCookie:
        let encoder = JSONEncoder()
        encoder.outputFormatting = options.contains(.jsonReadable) ? [.prettyPrinted, .sortedKeys] : []
        if let rawCookies = rawCookies as? EditThisCookie {
            outputData = try encoder.encode(rawCookies)
        } else {
            outputData = try encoder.encode(EditThisCookie(from: binaryCookies))
        }
    case .netscape:
        if let rawCookies = rawCookies as? NetscapeCookies {
            outputData = try BinaryDataEncoder().encode(rawCookies)
        } else {
            outputData = try BinaryDataEncoder().encode(NetscapeCookies(from: binaryCookies))
        }
    case .invalid:
        outputData = Data()
    }
    
    
    // MARK: - Convert (Write)
    try outputData.write(to: toURL)
    
}
catch let error {
    print(error.localizedDescription)
}
