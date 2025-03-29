// Test Rust-style action code generation
S: A+;
A: 'a' B* {
  print!("[");
  for i in 0..$#1 {
    let child_node = $n1[i]; // Use $n1[i] to get the i-th child node of B*
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
