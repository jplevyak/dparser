# Path to 100% Safe Rust in DParser

This document outlines the strategic refactoring plan to eliminate all `unsafe` blocks and raw pointer operations within the `dparser_lib` Rust port, fully transitioning from a "1:1 structural C port" to an idiomatic, pure Safe Rust framework.

## Phase 1: Pure Rust Table and State Structures
The core issue forcing `unsafe` usage today is the legacy layout of `D_ParserTables`, `D_State`, `D_Shift`, and `D_Reduction`. These are currently FFI `bindgen` imported C structs that heavily utilize internal pointers (e.g., `*mut D_State`).

**Actions:**
1. **Redefine Parser Constructs Idiomatically**:
   - Rewrite `D_State`, `D_Shift`, `D_Reduction`, `D_Pass`, etc., as pure Rust enumerations and structs holding `Vec<...>` indices instead of raw structural pointers.
   - Example: Instead of `shifts: *mut *mut D_Shift`, use a structured `shifts: Vec<ShiftId>` where `ShiftId` maps to an arena index.
2. **Revamp the Binary Table Loader (`tables.rs`)**:
   - Drop the `ptr::read_unaligned` patch methodology acting upon raw blob vector chunks.
   - Implement structured serialization (using the `bincode` or `serde` crates, or a safely mapped byte-buffer parser like `nom`) that safely unpacks byte arrays into owned Rust vectors.

## Phase 2: Natively Safe String & Loc Boundaries (`whitespace.rs`, `pnode.rs`)
Currently, `Loc` parsing mappings execute arbitrary pointer arithmetic like `input_base_ptr.add(...)` referencing the original C character arrays safely to bypass copying costs. 

**Actions:**
1. **Slice-based Context Boundaries**:
   - Replace base pointer offsets natively utilizing slice indexing.
   - The parser should hold a single `input: &[u8]` reference mapping bounds natively like `&input[snode.loc.s .. end_loc_s]`. This offloads strict evaluation to Rust’s internal bounds tracking securely natively.

## Phase 3: Graph Memory Management (AST)
Tomita’s GLR algorithm generates a dynamic, highly branched, and structurally acyclic/cyclic graph linking structural permutations (`SNode`, `PNode`, `ZNode`).

**Actions:**
1. **Dismantle `bindings::D_ParseNode` via Isolated Arenas**:
   - We already introduced rudimentary arena wrappers, but `D_ParseNode` structural logic strictly uses raw child pointers (`children: *mut *mut c_void`) for reduction building logic.
   - Introduce safe identifier nodes (`PNodeId`) using an arena crate (e.g., `id-arena` or `bumpalo`) to maintain shared trees structurally without violating the borrowing rules or causing memory leaks.
   - Nodes will explicitly own slice paths linking elements like `children: Vec<PNodeId>`.

## Phase 4: Idiomatic Closure Bindings (`builder.rs` & `tree.rs`)
The generated C-style bindings dynamically export `#[unsafe(no_mangle)] pub extern "C" fn dispatch_action` referencing raw memory values (e.g., `_children: *mut *mut c_void`).

**Actions:**
1. **Typed Action Dispatcher Definitions**:
   - Stop exporting standard actions as global FFI signatures.
   - Update `dparser_builder` to generate a match branch securely parsing safe Rust variants inside a strictly typed context block.
   - Parameters passed strictly utilize strongly typed references `children: &[&ParseNodeWrapper]`.

## Implementation Path Overview

* **Step 1:** Rewrite types (`types.rs`, `state.rs`) completely independently using arenas.
* **Step 2:** Port the generator (`make_dparser.c`) structural dumps into a formatted `JSON` or `bincode` mapping schema decoupling `sizeof` FFI logic altogether.
* **Step 3:** Overhaul `parse.rs` strictly replacing `unsafe` state offset loops utilizing strongly tracked Vector indexing paths (`states[state_id]`).
* **Step 4:** Deprecate `bindings.rs`. Remove `bindgen` entirely!

By migrating to idiomatic structures, compilation checks will mathematically guarantee freedom from crashes, dangling pointers (UB memory alignment bounds), or leaks natively during AST commitment mappings!
