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

pub fn alternation(first: *Nfa, secondaries: []*Nfa, allocator: std.mem.Allocator) !*Nfa {
    var nfa: *Nfa = first;
    for (secondaries) |secondary| {
        nfa = try alternationPair(nfa, secondary, allocator);
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

pub fn disjunction(first: *Nfa, secondaries: []*Nfa, allocator: std.mem.Allocator) !*Nfa {
    var nfa = first;
    for (secondaries) |secondary| {
        nfa = try disjunctionPair(nfa, secondary, allocator);
    }
    return nfa;
}

test "matches" {
    const abc = "abc";
    const dddd = "dddd";
    const eof = "";
    const mm = "mm";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var abcOrdddd = try disjunction(
        try alternation(
            try char('a', arena.allocator()),
            @constCast(&[_]*Nfa{
                try char('b', arena.allocator()),
                try char('c', arena.allocator()),
            }),
            arena.allocator(),
        ),
        @constCast(
            &[_]*Nfa{
                try repetition(try char('d', arena.allocator())),
            },
        ),
        arena.allocator(),
    );

    try std.testing.expect(try abcOrdddd.matches(abc));
    try std.testing.expect(try abcOrdddd.matches(dddd));
    try std.testing.expect(try abcOrdddd.matches(eof));
    try std.testing.expect(!try abcOrdddd.matches(mm));
}
