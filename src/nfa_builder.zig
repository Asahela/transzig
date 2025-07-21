const std = @import("std");
const Nfa = @import("nfa.zig").Nfa;
const State = @import("state.zig").State;
const Symbol = @import("symbol.zig").Symbol;
const SymbolTag = @import("symbol.zig").SymbolTag;

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

pub fn epsilon(allocator: std.mem.Allocator) !*Nfa {
    return try char(.{ .epsilon = {} }, allocator);
}

pub fn concatPair(first: *Nfa, second: *Nfa, allocator: std.mem.Allocator) !*Nfa {
    first.out.is_accepting = false;
    second.out.is_accepting = true;

    try first.out.addTransition(.{ .epsilon = {} }, second.in);

    const nfa = try allocator.create(Nfa);
    nfa.* = Nfa.create(first.in, second.out);
    return nfa;
}

pub fn concatOp(first: *Nfa, secondaries: []*Nfa, allocator: std.mem.Allocator) !*Nfa {
    var nfa: *Nfa = first;
    for (secondaries) |secondary| {
        nfa = try concatPair(nfa, secondary, allocator);
    }
    return nfa;
}

pub fn orPair(first: *Nfa, second: *Nfa, allocator: std.mem.Allocator) !*Nfa {
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

pub fn orOp(first: *Nfa, secondaries: []*Nfa, allocator: std.mem.Allocator) !*Nfa {
    var nfa = first;
    for (secondaries) |secondary| {
        nfa = try orPair(nfa, secondary, allocator);
    }
    return nfa;
}

pub fn repOp(nfa: *Nfa) !*Nfa {
    try nfa.in.addTransition(.{ .epsilon = {} }, nfa.out);
    try nfa.out.addTransition(.{ .epsilon = {} }, nfa.in);

    return nfa;
}
