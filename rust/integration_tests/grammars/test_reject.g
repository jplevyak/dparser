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

Rule: 'a' 'b' 'c' 
{
    $$.valid_match = false;
    return -1;
}
 | 'a' 'b' 'c'
{
    $$.valid_match = true;
};
