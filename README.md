# CookiesTool

This is a maintained fork of [BinaryCookies](https://github.com/interstateone/BinaryCookies).

Convert cookies between:

- BinaryCookies (Apple)
- EditThisCookie (JSON)
- Perl::LWP
- Netscape HTTP Cookie File (Mozilla, curl).
- JSON
- Property List (XML)

Supports macOS 10.15 and above, iOS 13.0 and above.

## TODOs

- Unit Tests
- Framework Target & SPM Support

## Usage

```
Usage: CookiesTool [OPTIONS]... [FILE]...
Convert between Apple BinaryCookies, EditThisCookie (JSON), Perl::LWP and Netscape HTTP Cookie File.

Command options are (-l is the default):
  -h | --help               show this message and exit
  -l | --lint               check the cookies file for syntax errors
  -c | --convert FORMAT     rewrite cookies file in format
  -o | --output PATH        specify file path name for result;
                            the -o option is used with -c, and is only useful
                            with one file argument;
  -r | --readable           if writing JSON, output in human-readable form

FORMAT is one of: binarycookies edit-this-cookie netscape perl-lwp
```

## File Format

### File

| Field           | Endianness | Type                 | Size        | Description                             |
|-----------------|------------|----------------------|-------------|-----------------------------------------|
| Magic           | BE         | UTF-8                | 4           | "cook", no terminator                   |
| Number of pages | BE         | Unsigned Int         | 4           |                                         |
| Page N size     | BE         | Unsigned Int         | 4           | Repeat for N pages                      |
| Page N          |            |                      | Page N size | Page N content                          |
| Checksum        | BE         | Unsigned Int         | 4           | Sum every 4th byte for each page        |
| Footer          | BE         |                      | 8           | 0x071720050000004b                      |
| Metadata        |            | Binary Property List |             | Contains NSHTTPCookieAcceptPolicy value |

### Page

| Field             | Endianness | Type         | Size          | Description          |
|-------------------|------------|--------------|---------------|----------------------|
| Header            | BE         |              | 4             | 0x00000100           |
| Number of cookies | LE         | Unsigned Int | 4             |                      |
| Cookie N offset   | LE         | Unsigned Int | 4             | Repeat for N cookies |
| Footer            |            |              | 4             | 0x00000000           |
| Cookie N          |            |              | Cookie N size | Cookie N content     |

### Cookie

| Field              | Endianness | Type         | Size | Description                                                                  |
|--------------------|------------|--------------|------|------------------------------------------------------------------------------|
| Size               | LE         | Unsigned Int | 4    | Size in bytes                                                                |
| Version            | LE         | Unsigned Int | 4    | 0 or 1                                                                       |
| Flags              | LE         | Bit field    | 4    | isSecure = 1, isHTTPOnly = 1 << 2, unknown1 = 1 << 3, unknown2 = 1 << 4      |
| Has port           | LE         | Unsigned Int | 4    | 0 or 1                                                                       |
| URL Offset         | LE         | Unsigned Int | 4    | Offset from the start of the cookie                                          |
| Name Offset        | LE         | Unsigned Int | 4    | Offset from the start of the cookie                                          |
| Path Offset        | LE         | Unsigned Int | 4    | Offset from the start of the cookie                                          |
| Value Offset       | LE         | Unsigned Int | 4    | Offset from the start of the cookie                                          |
| Comment Offset     | LE         | Unsigned Int | 4    | Offset from the start of the cookie, 0x00000000 if not present               |
| Comment URL Offset | LE         | Unsigned Int | 4    | Offset from the start of the cookie, 0x00000000 if not present               |
| Expiration         | LE         | Double       | 8    | Number of seconds since 00:00:00 UTC on 1 January 2001                       |
| Creation           | LE         | Double       | 8    | Number of seconds since 00:00:00 UTC on 1 January 2001                       |
| Port               | LE         | Unsigned Int | 2    | Only present if the "Has port" field is 1                                    |
| Comment            | LE         | String       |      | Null-terminated, optional                                                    |
| Comment URL        | LE         | String       |      | Null-terminated, optional                                                    |
| URL                | LE         | String       |      | Null-terminated                                                              |
| Name               | LE         | String       |      | Null-terminated                                                              |
| Path               | LE         | String       |      | Null-terminated                                                              |
| Value              | LE         | String       |      | Null-terminated                                                              |
