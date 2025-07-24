const std = @import("std");
const NfaBuilder = @import("nfa_builder.zig").NfaBuilder;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Error = @import("error.zig").Error;
const reportError = @import("error.zig").reportError;

pub fn run() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 3) {
        try reportError("Too many arguments.");
        return Error.RuntimeError;
    } else if (args.len == 2) {
        try reportError("Missing arguments.");
        return Error.RuntimeError;
    } else if (args.len == 1) {
        try stdout.print("\x1b[1;32mTranszig is a minimal ascii-based regular expression processor.\n\x1b[0mUsage: transzig [<regexp>] [<string>]\n", .{});
        try std.process.exit(64);
    }

    const regexp = args[1];
    const string = args[2];
    var tokenizer = Tokenizer.init(regexp, allocator);
    defer tokenizer.deinit();
    const tokens = try tokenizer.scanTokens();
    var parser = Parser.init(tokens);
    defer parser.deinit();
    const parse_tree = try parser.parse();
    var builder = NfaBuilder.init(parse_tree);
    defer builder.deinit();
    const nfa = try builder.build();
    try stdout.print("\x1b[1;32m{}\x1b[0m\n", .{try nfa.matches(string)});
}
