const std = @import("std");
const State = @import("state.zig").State;

pub const Nfa = struct {
    in: *State,
    out: *State,

    pub fn create(in: *State, out: *State) Nfa {
        return .{
            .in = in,
            .out = out,
        };
    }

    pub fn matches(self: *Nfa, string: []const u8) !bool {
        return try self.in.transits(string, null);
    }
};

pub fn epsilon(allocator: std.mem.Allocator) !*Nfa {
    return try char(.{ .epsilon = {} }, allocator);
}

pub fn char(character: u8, allocator: std.mem.Allocator) !*Nfa {
    const in_state = try allocator.create(State);
    const out_state = try allocator.create(State);
    in_state.* = State.init(allocator);
    out_state.* = State.init(allocator);

    out_state.is_accepting = true;

    try in_state.addTransition(.{ .alphabet = character }, out_state);

    const nfa = try allocator.create(Nfa);
    nfa.* = Nfa.create(in_state, out_state);
    return nfa;
}

pub fn repetition(nfa: *Nfa) !*Nfa {
    try nfa.in.addTransition(.{ .epsilon = {} }, nfa.out);
    try nfa.out.addTransition(.{ .epsilon = {} }, nfa.in);

    return nfa;
}

pub fn alternationPair(first: *Nfa, second: *Nfa, allocator: std.mem.Allocator) !*Nfa {
    first.out.is_accepting = false;
    second.out.is_accepting = true;

    try first.out.addTransition(.{ .epsilon = {} }, second.in);

    const nfa = try allocator.create(Nfa);
    nfa.* = Nfa.create(first.in, second.out);
    return nfa;
}

pub fn alternation(entries: []*Nfa, allocator: std.mem.Allocator) !*Nfa {
    var nfa: *Nfa = entries[0];
    const rest = entries[1..];
    for (rest) |entry| {
        nfa = try alternationPair(nfa, entry, allocator);
    }
    return nfa;
}

pub fn disjunctionPair(first: *Nfa, second: *Nfa, allocator: std.mem.Allocator) !*Nfa {
    first.out.is_accepting = false;
    second.out.is_accepting = false;

    const in_state = try allocator.create(State);
    const out_state = try allocator.create(State);
    in_state.* = State.init(allocator);
    out_state.* = State.init(allocator);

    out_state.is_accepting = true;

    try in_state.addTransition(.{ .epsilon = {} }, first.in);
    try in_state.addTransition(.{ .epsilon = {} }, second.in);
    try first.out.addTransition(.{ .epsilon = {} }, out_state);
    try second.out.addTransition(.{ .epsilon = {} }, out_state);

    const nfa = try allocator.create(Nfa);
    nfa.* = Nfa.create(in_state, out_state);
    return nfa;
}

pub fn disjunction(entries: []*Nfa, allocator: std.mem.Allocator) !*Nfa {
    var nfa: *Nfa = entries[0];
    const rest = entries[1..];
    for (rest) |entry| {
        nfa = try disjunctionPair(nfa, entry, allocator);
    }
    return nfa;
}

test "matches" {
    const Tokenizer = @import("tokenizer.zig").Tokenizer;
    const Parser = @import("parser.zig").Parser;
    const NfaBuilder = @import("nfa_builder.zig").NfaBuilder;
    const allocator = std.testing.allocator;

    {
        const test_cases = [_]struct {
            pattern: []const u8,
            strings: []const []const u8,
            expected: []const bool,
        }{
            .{ .pattern = "a", .strings = &[_][]const u8{ "a", "", "b" }, .expected = &[_]bool{ true, false, false } },
            .{ .pattern = "a*", .strings = &[_][]const u8{ "", "aa", "ab" }, .expected = &[_]bool{ true, true, false } },
            .{ .pattern = "ab", .strings = &[_][]const u8{ "ab", "a", "b" }, .expected = &[_]bool{ true, false, false } },
            .{ .pattern = "a|b", .strings = &[_][]const u8{ "ab", "a", "ac" }, .expected = &[_]bool{ false, true, false } },
        };

        for (test_cases) |tc| {
            var tokenizer = Tokenizer.init(tc.pattern, allocator);
            defer tokenizer.deinit();
            const tokens = try tokenizer.scanTokens();
            var parser = Parser.init(tokens);
            defer parser.deinit();
            const parse_tree = try parser.parse();
            var builder = NfaBuilder.init(parse_tree);
            defer builder.deinit();
            const nfa = try builder.build();

            for (tc.strings, 0..) |string, i| {
                try std.testing.expectEqual(tc.expected[i], try nfa.matches(string));
            }
        }
    }
}
