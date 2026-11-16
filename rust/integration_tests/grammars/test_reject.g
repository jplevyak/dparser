{
use dparser;

#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
    pub valid_match: bool,
}
}

start: Rule
{
    $$ = $0.clone();
};

// Two identical derivations: the first is rejected by its speculative action.
Rule: 'a' 'b' 'c' [ ${reject}; ]
{
    $$.valid_match = false;
}
 | 'a' 'b' 'c'
{
    $$.valid_match = true;
};
