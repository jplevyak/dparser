//! `grammar.rs`
//! The parse tables, as loaded from the binary tables written by `make_dparser -B`.

/// Symbol kinds (`D_SYMBOL_*` in `dparse_tables.h`).
pub const D_SYMBOL_NTERM: u32 = 1;
pub const D_SYMBOL_INTERNAL: u32 = 2;
pub const D_SYMBOL_EBNF: u32 = 3;
pub const D_SYMBOL_STRING: u32 = 4;
pub const D_SYMBOL_REGEX: u32 = 5;
pub const D_SYMBOL_CODE: u32 = 6;
pub const D_SYMBOL_TOKEN: u32 = 7;

/// Pass kinds (`D_PASS_*` in `dparse_tables.h`).
pub const D_PASS_PRE_ORDER: u32 = 0x0001;
pub const D_PASS_POST_ORDER: u32 = 0x0002;
pub const D_PASS_MANUAL: u32 = 0x0004;
pub const D_PASS_FOR_ALL: u32 = 0x0008;
pub const D_PASS_FOR_UNDEFINED: u32 = 0x0010;

/// Scanner kinds (`D_SCAN_*`).
pub const D_SCAN_ALL: u8 = 0;
pub const D_SCAN_LONGEST: u8 = 1;
pub const D_SCAN_MIXED: u8 = 2;
pub const D_SCAN_TRAILING: u8 = 3;

/// Operator associativity, for the `op_assoc` result of external scanners
/// (`D_ASSOC_*` in `dparse_tables.h`).
pub const D_ASSOC_NONE: u8 = 0x00;
pub const D_ASSOC_UNARY_LEFT: u8 = 0x09;
pub const D_ASSOC_UNARY_RIGHT: u8 = 0x0A;
pub const D_ASSOC_BINARY_LEFT: u8 = 0x11;
pub const D_ASSOC_BINARY_RIGHT: u8 = 0x12;

/// Index of a reduction in [`SafeGrammarTables::reductions`].
pub type ReductionId = u32;

#[derive(Debug, Clone)]
pub struct GrammarReduction {
    pub nelements: u16,
    pub symbol: u16,
    pub action_index: i32,
    pub op_assoc: u16,
    pub rule_assoc: u16,
    pub op_priority: i32,
    pub rule_priority: i32,
}

#[derive(Debug, Clone)]
pub struct GrammarShift {
    pub symbol: u16,
    pub shift_kind: u8,
    pub op_assoc: u8,
    pub op_priority: i32,
    pub term_priority: i32,
    pub action_index: i32,
    pub has_speculative_code: bool,
}

#[derive(Debug, Clone)]
pub struct GrammarRightEpsilonHint {
    pub depth: u16,
    pub preceeding_state: u16,
    pub reduction: ReductionId,
}

#[derive(Debug, Clone)]
pub struct GrammarErrorRecoveryHint {
    pub depth: u16,
    pub symbol: u16,
    pub string: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct GrammarState {
    /// Bit set of the symbols with a goto from this state.
    pub goto_valid: Vec<u8>,
    pub goto_table_offset: i32,
    pub reductions: Vec<ReductionId>,
    pub right_epsilon_hints: Vec<GrammarRightEpsilonHint>,
    pub error_recovery_hints: Vec<GrammarErrorRecoveryHint>,
    pub has_shifts: bool,
    /// The state uses an external scanner (`${scan ...}` or `${scanner ...}`).
    pub has_scanner_code: bool,
    pub accept: bool,
    pub reduces_to: i32,

    pub scan_kind: u8,
    pub scanner_size: u8,
    // Addresses inside `SafeGrammarTables::_binary_data` of the scanner DFA
    // (see scan.rs).  Zero when the state has no scanner.
    pub scanner_table: usize,
    pub transition_table: usize,
    pub accepts_diff: usize,
}

#[derive(Debug, Clone)]
pub struct GrammarSymbol {
    pub kind: u32,
    pub name: String,
    /// The start state for this nonterminal, or -1.
    pub start_symbol: i32,
}

#[derive(Debug, Clone)]
pub struct GrammarPass {
    pub name: String,
    pub kind: u32,
    pub index: u32,
}

#[derive(Debug, Clone)]
pub struct SafeGrammarTables {
    pub states: Vec<GrammarState>,
    pub goto_table: Vec<u16>,
    pub reductions: Vec<GrammarReduction>,
    pub whitespace_state: u32,
    /// The grammar declares a whitespace function (`${declare whitespace}`).
    pub has_default_white_space: bool,
    pub save_parse_tree: bool,
    pub symbols: Vec<GrammarSymbol>,
    pub passes: Vec<GrammarPass>,
    /// Kind of each symbol (D_SYMBOL_NTERM, D_SYMBOL_INTERNAL, ...), indexed by symbol.
    pub symbol_kinds: Vec<u32>,
    pub _binary_data: Vec<u64>, // owns the memory the scanner tables point into
}

impl SafeGrammarTables {
    #[inline]
    pub fn goto_valid(&self, state: usize, symbol: usize) -> bool {
        let v = &self.states[state].goto_valid;
        let byte = symbol >> 3;
        byte < v.len() && (v[byte] & (1 << (symbol & 7))) != 0
    }

    /// The state reached from `state` on `symbol`; only meaningful when
    /// `goto_valid(state, symbol)`.
    #[inline]
    pub fn goto_state(&self, state: usize, symbol: usize) -> usize {
        let idx = symbol as isize - self.states[state].goto_table_offset as isize;
        self.goto_table[idx as usize] as usize - 1
    }

    pub fn symbol_name(&self, symbol: usize) -> &str {
        self.symbols.get(symbol).map(|s| s.name.as_str()).unwrap_or("")
    }

    pub fn symbol_kind(&self, symbol: usize) -> u32 {
        self.symbols.get(symbol).map(|s| s.kind).unwrap_or(0)
    }
}
