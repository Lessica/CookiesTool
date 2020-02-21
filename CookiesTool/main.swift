import Foundation
import BinaryCodable

func usage() {
    print("""
Usage: CookiesTool [OPTIONS]... [FILE]...
Convert between Apple BinaryCookies, Property List, JSON, Netscape HTTP Cookie File.

Command options are (-l is the default):
  -h | --help               show this message and exit
  -l | --lint               check the cookies file for syntax errors
  -c | --convert FORMAT     rewrite cookies file in format
  -o | --output PATH        specify file path name for result;
                            the -o option is used with -c, and is only useful
                            with one file argument;
  -r | --readable           if writing JSON, output in human-readable form

FORMAT is one of: binary plist-binary plist-xml json netscape
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
    case binary      = "binary"
    case plistBinary = "plist-binary"
    case plistXML    = "plist-xml"
    case JSON        = "json"
    case netscape    = "netscape"
}

struct Options: OptionSet {
    let rawValue: Int
    static let jsonReadable = Options(rawValue: 1 << 0)
}

do {
    
    var mode = Mode.lint
    var format = Format.binary
    var options: Options = []
    var outputPath: String? = nil
    var inputPath: String? = nil

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
            format = argiFormat
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
            inputPath = args[i]
        }
        
        i = i + 1
    }
    
    if mode == .help {
        usage()
        exit(EXIT_SUCCESS)
    }
    
    guard let path = inputPath else {
        throw CustomError.missingArgumentFile
    }
    
    let url = URL(fileURLWithPath: path, relativeTo: nil)
    let data = try Data(contentsOf: url)
    
    var binaryCookies: BinaryCookies
    if let tryDecodeCookies = try? BinaryDataDecoder().decode(BinaryCookies.self, from: data) {
        binaryCookies = tryDecodeCookies
    }
    else if let tryDecodeCookies = try? JSONDecoder().decode(BinaryCookies.self, from: data) {
        binaryCookies = tryDecodeCookies
    }
    else if let tryDecodeCookies = try? PropertyListDecoder().decode(BinaryCookies.self, from: data) {
        binaryCookies = tryDecodeCookies
    }
    else if let tryDecodeCookies = try? BinaryDataDecoder().decode(NetscapeCookies.self, from: data) {
        if mode == .lint {
            dump(tryDecodeCookies)
            exit(EXIT_SUCCESS)
        }
        
        binaryCookies = BinaryCookies(from: tryDecodeCookies)
    }
    else {
        throw CustomError.invalidFileFormat
    }
    
    if mode == .lint {
        dump(binaryCookies)
        exit(EXIT_SUCCESS)
    }
    
    guard let toPath = outputPath else {
        throw CustomError.missingOptionOutput
    }
    
    let toURL = URL(fileURLWithPath: toPath, relativeTo: nil)
    
    var outputData: Data? = nil
    if format == .binary {
        outputData = try BinaryDataEncoder().encode(binaryCookies)
    }
    else if format == .plistBinary {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        outputData = try encoder.encode(binaryCookies)
    }
    else if format == .plistXML {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        outputData = try encoder.encode(binaryCookies)
    }
    else if format == .JSON {
        let encoder = JSONEncoder()
        if options.contains(.jsonReadable) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        outputData = try encoder.encode(binaryCookies)
    }
    else if format == .netscape {
        outputData = try BinaryDataEncoder().encode(NetscapeCookies(from: binaryCookies))
    }
    
    try outputData!.write(to: toURL)
}
catch let error {
    print(error.localizedDescription)
}
