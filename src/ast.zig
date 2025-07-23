const std = @import("std");

pub const Kind = enum {
    disjunction,
    alternation,
    repetition,
    char,
};

pub const RegExp = union(Kind) {
    disjunction: Disjunction,
    alternation: Alternation,
    repetition: Repetition,
    char: Char,
};

pub const Disjunction = struct { left: *const RegExp, right: *const RegExp };

pub const Alternation = struct { expressions: []*const RegExp };

pub const Repetition = struct { expression: *const RegExp };

pub const Char = struct { value: u8 };
