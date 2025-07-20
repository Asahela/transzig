const std = @import("std");
const Symbol = @import("symbol.zig").Symbol;
const SymbolTag = @import("symbol.zig").SymbolTag;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;

const State = struct {
    id: usize,
    is_accepting: bool,
    transitions: AutoHashMap(Symbol, AutoHashMap(*State, void)),
    allocator: Allocator,

    pub fn init(allocator: Allocator) State {
        return .{
            .id = 0,
            .is_accepting = false,
            .transitions = AutoHashMap(Symbol, AutoHashMap(*State, void)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *State) void {
        var iterator = self.transitions.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.transitions.deinit();
    }

    pub fn addTransition(self: *State, symbol: Symbol, state: *State) !void {
        var states: AutoHashMap(*State, void) =
            if (self.transitions.get(symbol)) |existing_states|
                existing_states
            else
                AutoHashMap(*State, void).init(self.allocator);
        try states.put(state, {});
        try self.transitions.put(symbol, states);
    }
};

test "addTransition" {
    const allocator = std.testing.allocator;

    {
        var a = State.init(allocator);
        defer a.deinit();

        try std.testing.expectEqual(0, a.transitions.count());
    }

    {
        var a = State.init(allocator);
        defer a.deinit();
        var b = State.init(allocator);
        defer b.deinit();
        const symbol: Symbol = .{ .alphabet = 'a' };

        try a.addTransition(symbol, &b);

        try std.testing.expectEqual(1, a.transitions.count());
        try std.testing.expect(a.transitions.contains(symbol));
    }

    {
        var a = State.init(allocator);
        defer a.deinit();
        var b = State.init(allocator);
        defer b.deinit();
        var c = State.init(allocator);
        defer c.deinit();
        var d = State.init(allocator);
        defer d.deinit();

        try a.addTransition(.{ .alphabet = 'a' }, &b);
        try a.addTransition(.{ .alphabet = 'a' }, &c);
        try a.addTransition(.{ .epsilon = {} }, &d);

        try std.testing.expectEqual(2, a.transitions.count());
        try std.testing.expect(a.transitions.contains(.{ .alphabet = 'a' }));
        try std.testing.expect(a.transitions.contains(.{ .epsilon = {} }));
        try std.testing.expectEqual(2, a.transitions.get(.{ .alphabet = 'a' }).?.count());
    }
}
