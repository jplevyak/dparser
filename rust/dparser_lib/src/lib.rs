#![allow(unsafe_op_in_unsafe_fn)]
pub mod arena;
pub mod binary_format;
pub mod builder;
pub mod grammar;
pub mod epsilon;
pub mod error;
pub mod parse;
pub mod parser_ctx;
pub mod pnode;
pub mod priority;
pub mod reduce;
pub mod scan;
pub mod shift;
pub mod tables;
pub mod tree;
pub mod types;
pub mod whitespace;
pub use builder::build_actions;
use crate::types::ParseNode;

pub type DispatchActionFn<G, N> = fn(
    action_index: i32,
    ps: &mut ParseNode<'_, N>,
    children: &mut [ParseNode<'_, N>],
    parser: &mut Parser<G, N>,
) -> i32;
// Legacy helper mechanisms erased to use pure Rust slices efficiently directly against String slices!
pub struct Parser<G: 'static, N: 'static> {
    pub initial_globals: Option<*mut G>,
    _tables_container: crate::grammar::SafeGrammarTables,
    dispatch_action: Option<DispatchActionFn<G, N>>,
    pub syntax_error_fn: Option<fn(&mut Self)>,
    pub ambiguity_fn: Option<fn(&mut Self, usize, &mut [ParseNode<'_, N>]) -> usize>,
    pub save_parse_tree: bool,
    _phantom_g: std::marker::PhantomData<G>,
    _phantom_n: std::marker::PhantomData<N>,
}

impl<G: 'static, N: 'static + Default> Parser<G, N> {
    pub fn new(
        tables_bytes: &[u8],
        dispatch_action: Option<DispatchActionFn<G, N>>,
    ) -> Result<Self, &'static str> {
        let tables_container = crate::tables::BinaryTables::from_bytes(tables_bytes)?;

        Ok(Parser {
            initial_globals: None,
            _tables_container: tables_container,
            dispatch_action,
            syntax_error_fn: None,
            ambiguity_fn: None,
            save_parse_tree: false,
            _phantom_g: std::marker::PhantomData,
            _phantom_n: std::marker::PhantomData,
        })
    }

    pub fn globals(&mut self) -> &mut G {
        unsafe { &mut *self.initial_globals.unwrap() }
    }

    pub fn parse<'a>(
        &mut self,
        input: &'a str,
        initial_globals: Option<&'a mut G>,
    ) -> Option<crate::types::ParseNode<'a, N>>
    where
        N: Default + Clone,
    {
        self.initial_globals = initial_globals.map(|g| g as *mut G);
        let input_bytes = input.as_bytes();
        let tables_ref_ptr_hack = &self._tables_container as *const _;

        let mut ctx = crate::parser_ctx::ParserContext::new(
            input_bytes,
        );

        let native_result = crate::parse::dparse(&mut ctx, unsafe { &*tables_ref_ptr_hack }, input_bytes);

        if let Some(s_id) = native_result {
            let snode = ctx.snode_arena.get(s_id.0).unwrap();
            if let Some(z_id) = snode.zns.first() {
                let znode = ctx.znode_arena.get(z_id.0).unwrap();
                if let Some(pn_id) = znode.pn {
                    return Some(crate::tree::build_parse_tree(&mut ctx, pn_id, self, self.dispatch_action));
                }
            }
        }
        
        None
    }

    pub fn set_save_parse_tree(&mut self, b: bool) {
        self.save_parse_tree = b;
    }
}
