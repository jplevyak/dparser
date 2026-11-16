{
use dparser;

#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
    pub items: Vec<String>,
}
}

start: item* {
    for n in $n0* {
        $$.items.push(n.string.to_string());
    }
};

item: "[a-z]+" | "[0-9]+";
