

#[derive(Debug, Clone)]
pub struct SafeGrammarTables {
    pub states: Vec<GrammarState>,
    pub goto_table: Vec<u16>,
    pub whitespace_state: u32,
    pub save_parse_tree: bool,
    pub _binary_data: Vec<u64>, // Natively maintains ownership over buffer containing pointer mappings cleanly!
}

#[derive(Debug, Clone)]
pub struct GrammarState {
    pub goto_valid: Vec<u8>,
    pub goto_table_offset: i32,
    pub reductions: Vec<GrammarReduction>,
    pub right_epsilon_hints: Vec<GrammarRightEpsilonHint>,
    pub shifts: Vec<GrammarShift>, 
    pub accept: u8,
    pub reduces_to: i32,

    pub scan_kind: u8,
    pub scanner_size: u8,
    // Provide a raw memory address statically linking the scanner matrix mapping!
    // This allows scan.rs to temporarily execute natively across the Sparse arrays!
    pub scanner_table: usize,
    pub transition_table: usize,
    pub accepts_diff: usize,
}

#[derive(Debug, Clone)]
pub struct GrammarReduction {
    pub nelements: u16,
    pub symbol: u16,
    pub action_index: i32,
    pub op_assoc: u16,
    pub rule_assoc: u16,
    pub op_priority: i32,
    pub rule_priority: i32,
    pub speculative_code: i32, // placeholder mappings vs Enum
    pub final_code: i32,
}

#[derive(Debug, Clone)]
pub struct GrammarShift {
    pub symbol: u16,
    pub shift_kind: u8,
    pub op_assoc: u8,
    pub op_priority: i32,
    pub term_priority: i32,
    pub action_index: i32,
    pub speculative_code: i32,
}

#[derive(Debug, Clone)]
pub struct GrammarRightEpsilonHint {
    pub depth: u16,
    pub preceeding_state: u16,
    pub reduction: GrammarReduction,
}
