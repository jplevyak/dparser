# DParser Agent Guide

This document provides necessary context and instructions for AI Agents to effectively write, debug, explain, and optimize DParser grammars.

## 1. Overview
DParser is a scannerless GLR (Generalized LR) parser generator.
- **Scannerless**: It does not use a separate lexer. Lexical analysis is performed by the parser itself using character-level productions.
- **GLR**: It can handle nondeterministic and ambiguous grammars by forking the parse stack. It supports local and global ambiguity resolution.
- **Output**: Generates C code (or optionally other languages via headers) for parsing tables and actions.

## 2. Grammar Syntax (from `grammar.g`)

A DParser grammar consists of a series of top-level statements: global code, productions, or include statements.

### 2.1 Productions
Productions define the non-terminals.
Format: `name: rules;` or `name: rule1 | rule2;`

Examples:
```yacc
program: statement+;
statement: expression ';';
expression: term '+' term;
```

### 2.2 Elements
Rules are sequences of elements.
- **Strings**: `'string'` (e.g., `'while'`, `'+'`)
- **Regex**: `"regex"` (e.g., `"[a-z]+"`) - Supported: `[]` ranges, `*`, `+`, `?`.
- **Unicode**: `U+XXXX` or `u+xxxx`.
- **Identifiers**: References to other productions.
- **Parentheses**: `( ... )` for grouping.
- **EBNF Operators**:
    - `?`: Optional (0 or 1)
    - `*`: Zero or more
    - `+`: One or more
    - `@N`: Exactly N times
    - `@N:M`: Between N and M times

### 2.3 Actions
Actions are C code blocks executed during parsing.
- **Final Actions**: `{ ... }` Executed when a reduction is committed.
- **Speculative Actions**: `[ ... ]` Executed during speculative parsing (may be rolled back).
- **Embedded Actions**: `rule: A { action } B;` (Parsed as a sub-rule).

### 2.4 Priorities and Associativity
Used to resolve ambiguities.
- **Terminals**: `term $term priority` (e.g., `term $term 1`)
- **Operators**: `$binary_op_left`, `$binary_op_right`, `$unary_op_left`, etc.
- **Rules**: `rule $left 1` or `rule $right 2`.

Example:
```yacc
E: E '+' E $binary_op_left 1 | E '*' E $binary_op_left 2;
```

### 2.5 Variables in Actions
- `$0`, `$1`, ...: User parse node state (`user` struct) of child nodes.
- `$$`: User parse node state of the current node.
- `$n0`, `$n1`, ...: System parse node state (`D_ParseNode`) of child nodes.
- `$n`: System parse node state of the current node.
- `${scope}`: Current symbol table scope.
- `start_loc.s`: Pointer to start of the matched string.
- `end`: Pointer to end of the matched string.

## 3. Ambiguity Resolution
DParser uses a sequence of rules to resolve ambiguities:
1.  **Priorities**: Highest priority rule/operator wins.
2.  **Greediness**: Longest match wins (unless disabled).
3.  **Height**: Shortest derivation tree wins.
4.  **User Function**: Custom C function to select the best parse node.

## 4. Special Directives
- **Global Code**: `{ ... }` at top level.
- **Passes**: `${pass pass_name type}` to define traversal passes.
- **Tokenizers**: `${declare tokenize ...}` to force tokenizer behavior for subsets of the grammar.
- **Longest Match**: `${declare longest_match ...}`.

## 5. DParser Self-Definition (Crucial for Understanding)
The following is the grammar of DParser itself (`grammar.g`), which defines the valid syntax for any DParser grammar. Use this as the ground truth for syntax.

```yacc
grammar: top_level_statement*;
top_level_statement: global_code | production | include_statement;

include_statement: 'include' regex;

global_code
  : '%<' balanced_code* '%>'
  | curly_code
  | '${scanner' balanced_code+ '}'
  | '${declare' declarationtype identifier* '}'
  | '${token' token_identifier+ '}'
  | '${pass' identifier pass_types '}'
  ;

production
  : production_name ':' rules ';'
  | production_name '::=' rules ';'
  | ';'
  ;

rules : rule ('|' rule)*;

rule : (element element_modifier*)* simple_element element_modifier* rule_modifier* rule_code;

simple_element
  : string | regex | unicode_char | identifier
  | '${scan' balanced_code+ '}'
  | '(' rules ')'
  ;

element
  : simple_element
  | bracket_code
  | curly_code
  ;

element_modifier
  : '$term' integer
  | '$name' (string|regex)
  | '/i'
  | '?' | '*' | '+' | '@' integer | '@' integer ':' integer
  ;

rule_modifier : rule_assoc? rule_priority | external_action;

rule_assoc
  : '$unary_op_right' | '$unary_op_left' | '$binary_op_right' | '$binary_op_left'
  | '$unary_right' | '$unary_left' | '$binary_right' | '$binary_left'
  | '$right' | '$left'
  ;

rule_code : speculative_code? final_code? pass_code* ;

curly_code: '{' balanced_code* '}';
bracket_code: '[' balanced_code* ']';
```

## 6. Tips for AI Agents
- **Debugging**: If a parse fails, check for:
    - Missing whitespace handling (define `whitespace` production).
    - Ambiguities that DParser couldn't resolve (use `verbose_level` in `D_Parser`).
    - Incorrect regex syntax (DParser regex is simple).
- **Optimization**:
    - Use tokenizers (`${declare tokenize ...}`) for keywords/identifiers if context-sensitivity is not needed.
    - Use priorities to prune the search space early.
- **Writing Actions**:
    - Remember that `start_loc.s` and `end` are pointers into the input buffer; they are NOT null-terminated strings. Use `dup_str` or similar if you need a C string.
    - Use `$n` for access to location/symbol info, logic often needs to check `$n0.start_loc.line`.

## 7. C API Reference (`dparse.h`)
Important structures for writing custom actions or drivers:

```c
typedef struct D_ParseNode {
  int symbol;
  d_loc_t start_loc;
  char *end;
  char *end_skip;
  struct D_Scope *scope;
  D_ParseNode_User user; // User-defined data
} D_ParseNode;

typedef struct D_Parser {
  // ... options like initial_globals, syntax_error_fn ...
  int syntax_errors;
} D_Parser;

D_Parser *new_D_Parser(struct D_ParserTables *t, int sizeof_ParseNode_User);
D_ParseNode *dparse(D_Parser *p, char *buf, int buf_len);
int d_get_number_of_children(D_ParseNode *pn);
D_ParseNode *d_get_child(D_ParseNode *pn, int child);
```
