const std = @import("std");
const State = @import("state.zig").State;
const builder = @import("nfa_builder.zig");
const Symbol = @import("symbol.zig").Symbol;
const SymbolTag = @import("symbol.zig").SymbolTag;

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

test "matches" {
    const abc = "abc";
    const dddd = "dddd";
    const eof = "";
    const mm = "mm";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var abcOrdddd = try builder.orOp(
        try builder.concatOp(
            try builder.char('a', arena.allocator()),
            @constCast(&[_]*Nfa{
                try builder.char('b', arena.allocator()),
                try builder.char('c', arena.allocator()),
            }),
            arena.allocator(),
        ),
        @constCast(
            &[_]*Nfa{
                try builder.repOp(try builder.char('d', arena.allocator())),
            },
        ),
        arena.allocator(),
    );

    try std.testing.expect(try abcOrdddd.matches(abc));
    try std.testing.expect(try abcOrdddd.matches(dddd));
    try std.testing.expect(try abcOrdddd.matches(eof));
    try std.testing.expect(!try abcOrdddd.matches(mm));
}
