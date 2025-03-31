// Test Rust-style action code generation
S: A+;
A: 'a' B* {
  print!("[");
  // Use $n1* to get an iterator/Vec over the children of B*
  for child_node in $n1* { 
    let start_char = unsafe { *child_node.start_loc.s as char }; // Access start_loc.s
    print!("({})", start_char);
  }
  println!("]");
};
B: 'b' | 'B';

%%
abB
--
[(b)(B)]
