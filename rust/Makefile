all:
	cargo build --workspace

test:
	cargo test --workspace

clean:
	cargo clean
	rm -f a.out test_head.c test_offset.c

bindgen:
	bindgen ../dparse.h -o dparser_lib/src/binary_format.rs
