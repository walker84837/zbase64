# zbase64

> Zig port of the `base64` command-line utility

A thin wrapper around Zig's [std.base64](https://ziglang.org/documentation/0.14.0/std/#std.base64) de/encoder. Because it uses only the Zig standard library, it should compile anywhere Zig does.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [Building](#building)
- [Usage](#usage)
  - [Options](#options)
  - [Examples](#examples)
- [Validation](#validation)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Features

The features are essentially the same as the coreutils `base64` command, namely:
- Basics, **encode** and **decode** arbitrary data into Base64 or from Base64 data.

Other features present in the `base64 --help` menu:
- **Ignore garbage** when decoding (whitespace, non-alphabet bytes).
- **Line wrapping** for encoded output, customizable or disabled.
- **Cross-platform** - for Linux, macOS, Windows, etc.

## Installation

You'll need the [latest tagged version](https://github.com/walker84837/zbase64/blob/663c9a2df38442399c312cbb143aa4b6b4f67631/.github/workflows/zig.yml#L28-L39) installed. See <https://ziglang.org/download/> if you don't have it yet.

Clone this repo:

```sh
git clone https://github.com/walker84837/zbase64.git
cd zbase64
```

### Building

Since the code uses a few external libraries, namely for CLI handling,
```sh
zig build
```

You can use different [build modes](https://zig.guide/master/build-system/build-modes) as you wish.

This produces a `zbase64` (or `zbase64.exe` on Windows) at `zig-out/bin`. You can move it in a folder that's in your `$PATH` or package it accordingly.

## Usage

```txt
Usage: zbase64 [OPTION]... [FILE]

With no FILE, or when FILE is -, read standard input.

Mandatory arguments to long options are mandatory for short options too.
-d, --decodedecode data
-i, --ignore-garbagewhen decoding, ignore non-alphabet characters
-w, --wrap=COLS wrap encoded lines after COLS characters (default 76).
Use 0 to disable line wrapping
--helpdisplay this help and exit
--version output version information and exit
```

- If `FILE` is omitted or `-`, data is read from stdin.
- Output is always written to stdout.

### Options

| Short | Long | Description |
|-------|--------------------|---------------------------------------------------------------|
| `-d`| `--decode` | Decode Base64 input instead of encoding.|
| `-i`| `--ignore-garbage` | When decoding, ignore non-alphabet characters (e.g., whitespace). |
| `-w`| `--wrap=COLS`| Wrap encoded output every `COLS` characters (default: 76). Set to `0` for no wrapping. |
| | `--help` | Show this help message and exit.|
| | `--version`| Print version and exit. |

### Examples

Encode a file:

```sh
zbase64 myfile.bin > myfile.b64
```

Decode a Base64 stream:

```sh
zbase64 --decode myfile.b64 > myfile.out
```

Ignore non-Base64 data on decode (e.g., pasted from emails with line numbers):

```sh
zbase64 -d -i corrupted_input.txt > clean_output.bin
```

Disable line wrapping on encode:

```sh
zbase64 --wrap=0 README.md > readme.b64
```

Read from stdin / write to stdout:

```sh
cat picture.png | zbase64 > picture.b64
cat picture.b64 | zbase64 -d > picture_decoded.png
```

## Validation

I added a thin function to check whether the base64 is valid only if:

1. The input is non-empty
2. Its length is a multiple of 4.
3. Decoding succeeds without error under the standard Base64 alphabet and padding rules.

If you run with `--decode` and the input is invalid, the program exits with an error.

### Testing

Run Zig's test harness:

```sh
zig build test
```

This will execute the built-in tests, including:

- `min(a, b)` correctness
- `isBase64Valid` on valid and clearly invalid strings

## Contributing

Bug reports and pull requests are welcome! Please open an issue first if you're planning a big change. Follow [Zig's naming conventions](ziglang.org/documentation/master/#Style-Guide) and add tests for new functionality.

## License

[MIT License](LICENSE)
