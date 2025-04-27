const std = @import("std");
const argsParser = @import("args");
const base64 = std.base64;

pub const VERSION = "1.0.0";

fn printUsage(exeName: ?[:0]const u8) void {
    const name = exeName orelse "";

    std.debug.print(
        "Usage: {s} [OPTION]... [FILE]\n" ++
            "With no FILE, or when FILE is -, read standard input.\n\n" ++
            "Mandatory arguments to long options are mandatory for short options too.\n" ++
            "  -d, --decode          decode data\n" ++
            "  -i, --ignore-garbage  when decoding, ignore non-alphabet characters\n" ++
            "  -w, --wrap=COLS       wrap encoded lines after COLS characters (default 76).\n" ++
            "                          Use 0 to disable line wrapping\n" ++
            "      --help            display this help and exit\n" ++
            "      --version         output version information and exit\n",
        .{name},
    );
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const parsed = argsParser.parseForCurrentProcess(struct {
        decode: bool = false,
        @"ignore-garbage": bool = false,
        wrap: usize = 76,
        help: bool = false,
        version: bool = false,

        pub const shorthands = .{
            .d = "decode",
            .i = "ignore-garbage",
            .w = "wrap",
        };
    }, allocator, .print) catch |err| {
        std.debug.print("Error parsing options: {}\n", .{err});
        return;
    };
    defer parsed.deinit();

    const opts = parsed.options;
    const exeName = parsed.executable_name;

    if (opts.help) {
        printUsage(exeName);
        return;
    }
    if (opts.version) {
        std.debug.print("{s}\n", .{VERSION});
        return;
    }

    const infile = if (parsed.positionals.len > 0) parsed.positionals[0] else "-";
    var r: std.fs.File.Reader = undefined;

    if (std.mem.eql(u8, infile, "-")) {
        r = std.io.getStdIn().reader();
    } else {
        const file = try std.fs.cwd().openFile(infile, .{ .mode = .read_only });
        defer file.close();
        r = file.reader();
    }
    const reader = r;

    const stdout = std.io.getStdOut().writer();

    // 4) Read all input into memory
    const input = try reader.readAllAlloc(allocator, 4096);
    defer allocator.free(input);

    // 5) Branch on encode vs decode
    if (opts.decode) {
        if (opts.@"ignore-garbage") {
            const ignore = [_]u8{ '\n', '\r', ' ', '\t' };
            var decoder_with_ignore = base64.Base64DecoderWithIgnore.init(base64.standard_alphabet_chars, '=', &ignore);
            const maxOut = try decoder_with_ignore.calcSizeUpperBound(input.len);
            const outBuf = try allocator.alloc(u8, maxOut);
            const outLen = try decoder_with_ignore.decode(outBuf, input);
            try stdout.writeAll(outBuf[0..outLen]);
        } else {
            var decoder = base64.Base64Decoder.init(base64.standard_alphabet_chars, '=');
            const exactSize = try decoder.calcSizeForSlice(input);
            const outBuf = try allocator.alloc(u8, exactSize);
            try decoder.decode(outBuf, input);
            try stdout.writeAll(outBuf);
        }
    } else {
        var encoder = base64.Base64Encoder.init(base64.standard_alphabet_chars, '=');
        const encSize = encoder.calcSize(input.len);
        const encBuf = try allocator.alloc(u8, encSize);
        const encSlice = encoder.encode(encBuf, input);

        if (opts.wrap != 0) {
            var idx: usize = 0;
            while (idx < encSlice.len) : (idx += opts.wrap) {
                const len = min(opts.wrap, encSlice.len - idx);
                try stdout.writeAll(encSlice[idx .. idx + len]);
                try stdout.writeAll("\n");
            }
        } else {
            try stdout.writeAll(encSlice);
        }
    }
}

pub fn min(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (a < b) a else b;
}
