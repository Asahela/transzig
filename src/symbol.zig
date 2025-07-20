pub const SymbolTag = enum { epsilon, alphabet };
pub const Symbol = union(SymbolTag) { epsilon, alphabet: u8 };
