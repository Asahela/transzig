const std = @import("std");

pub const Error = error{ RuntimeError, ParseError, ScanError };

pub fn reportError(message: []const u8) !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("\x1b[1;31mError : {s}\x1b[0m\n", .{message});
}
