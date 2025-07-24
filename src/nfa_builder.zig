const std = @import("std");
const nfa = @import("nfa.zig");
const ast = @import("ast.zig");

pub const NfaBuilder = struct {
    arena: std.heap.ArenaAllocator,
    pattern: *const ast.RegExp,

    pub fn init(pattern: *const ast.RegExp) NfaBuilder {
        return .{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            .pattern = pattern,
        };
    }

    pub fn deinit(self: *NfaBuilder) void {
        self.arena.deinit();
    }

    pub fn build(self: *NfaBuilder) !*nfa.Nfa {
        return try self.buildFrom(self.pattern);
    }

    pub fn buildFrom(self: *NfaBuilder, exp: *const ast.RegExp) anyerror!*nfa.Nfa {
        return try switch (exp.*) {
            .disjunction => |dis_ast| self.buildDis(dis_ast),
            .alternation => |alt_ast| self.buildAlt(alt_ast),
            .repetition => |rep_ast| self.buildRep(rep_ast),
            .char => |char_ast| self.buildChar(char_ast),
        };
    }

    fn buildDis(self: *NfaBuilder, exp: ast.Disjunction) !*nfa.Nfa {
        return try nfa.disjunctionPair(try self.buildFrom(exp.left), try self.buildFrom(exp.right), self.arena.allocator());
    }

    fn buildAlt(self: *NfaBuilder, alts: ast.Alternation) !*nfa.Nfa {
        var alt_entries = std.ArrayList(*nfa.Nfa).init(self.arena.allocator());
        for (alts.expressions) |alt| {
            try alt_entries.append(try self.buildFrom(alt));
        }

        return try nfa.alternation(alt_entries.items, self.arena.allocator());
    }

    fn buildRep(self: *NfaBuilder, rep: ast.Repetition) !*nfa.Nfa {
        return try nfa.repetition(try self.buildFrom(rep.expression));
    }

    fn buildChar(self: *NfaBuilder, char: ast.Char) !*nfa.Nfa {
        return try nfa.char(char.value, self.arena.allocator());
    }
};
