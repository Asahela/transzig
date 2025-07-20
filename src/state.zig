const std = @import("std");
const Symbol = @import("symbol.zig").Symbol;
const SymbolTag = @import("symbol.zig").SymbolTag;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;

pub const State = struct {
    id: usize,
    is_accepting: bool,
    transitions: AutoHashMap(Symbol, AutoHashMap(*State, void)),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) State {
        return .{
            .id = 0,
            .is_accepting = false,
            .transitions = AutoHashMap(Symbol, AutoHashMap(*State, void)).init(allocator),
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *State) void {
        var iterator = self.transitions.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.transitions.deinit();
        self.arena.deinit();
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

    pub fn transits(self: *State, string: []const u8, visited_states: ?AutoHashMap(*State, void)) !bool {
        var visited =
            if (visited_states) |states|
                states
            else
                AutoHashMap(*State, void).init(self.arena.allocator());

        if (visited.contains(self)) return false;
        try visited.put(self, {});
        self.id = visited.count();

        if (string.len == 0) {
            if (self.is_accepting) return true;
            const epsilon_transitions: ?AutoHashMap(*State, void) = self.transitions.get(.{ .epsilon = {} });

            if (epsilon_transitions) |transitions| {
                var iterator = transitions.iterator();
                while (iterator.next()) |next_state|
                    if (try next_state.key_ptr.*.transits("", visited)) return true;
            }

            return false;
        }

        const current_symbol = string[0];
        const left_symbols = std.mem.trimLeft(u8, string, &[_]u8{current_symbol});
        const alphabet_transitions: ?AutoHashMap(*State, void) = self.transitions.get(.{ .alphabet = current_symbol });

        if (alphabet_transitions) |transitions| {
            var iterator = transitions.iterator();
            while (iterator.next()) |next_state| {
                if (try next_state.key_ptr.*.transits(left_symbols, null)) return true;
            }
        }

        const epsilon_transitions: ?AutoHashMap(*State, void) = self.transitions.get(.{ .epsilon = {} });

        if (epsilon_transitions) |transitions| {
            var iterator = transitions.iterator();
            while (iterator.next()) |next_state|
                if (try next_state.key_ptr.*.transits(string, visited)) return true;
        }

        return false;
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

test "transits" {
    const allocator = std.testing.allocator;

    {
        const whitespaces = "   ";
        const space = " ";
        const eof = "";

        const epsilon: Symbol = .{ .epsilon = {} };

        var in = State.init(allocator);
        defer in.deinit();
        var out = State.init(allocator);
        defer out.deinit();

        out.is_accepting = true;

        try in.addTransition(epsilon, &out);
        try out.addTransition(epsilon, &in);

        try std.testing.expectEqual(false, try in.transits(whitespaces, null));
        try std.testing.expectEqual(false, try in.transits(space, null));
        try std.testing.expectEqual(true, try in.transits(eof, null));
    }

    {
        const abc = "abc";
        const eof = "";

        var a = State.init(allocator);
        defer a.deinit();
        var b = State.init(allocator);
        defer b.deinit();
        var c = State.init(allocator);
        defer c.deinit();
        var d = State.init(allocator);
        d.is_accepting = true;
        defer d.deinit();

        try a.addTransition(.{ .alphabet = 'a' }, &b);
        try b.addTransition(.{ .alphabet = 'b' }, &c);
        try c.addTransition(.{ .alphabet = 'c' }, &d);
        try a.addTransition(.{ .epsilon = {} }, &d);

        try std.testing.expect(try a.transits(abc, null));
        try std.testing.expect(try a.transits(eof, null));
    }

    {
        const test_cases = [_][]const u8{ "", "a", "aaa", "aaaa" };

        const a: Symbol = .{ .alphabet = 'a' };
        const epsilon: Symbol = .{ .epsilon = {} };

        var in = State.init(allocator);
        defer in.deinit();
        var out = State.init(allocator);
        defer out.deinit();
        out.is_accepting = true;

        try in.addTransition(a, &out);
        try in.addTransition(epsilon, &out);
        try out.addTransition(epsilon, &in);

        for (test_cases) |tc| {
            try std.testing.expect(try in.transits(tc, null));
        }
    }
}
