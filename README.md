# CookiesTool

You may need to download & install [Swift 5 Runtime Support for Command Line Tools](https://support.apple.com/kb/DL1998) to run this tool on macOS version prior to 10.14.4.

## Usage

```
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
```
