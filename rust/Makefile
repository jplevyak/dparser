all:
	cargo build --workspace

test:
	cargo test --workspace

clean:
	cargo clean
	rm -f a.out test_head.c test_offset.c
	$(MAKE) clean-stray

clean-stray:
	rm -rf ansic verilog tests
	rm -f *.c *.h *.g mkdep DParser.Makefile
	rm -f 4calc.in make_dparser.cat make_dparser.1
	rm -f 1 tmp.g

prep-publish:
	cp ../*.c ../*.h ../*.g ../mkdep .
	cp ../Makefile DParser.Makefile
	cp -R ../ansic ../verilog ../tests .

bindgen:
	bindgen ../dparse.h -o src/binary_format.rs
