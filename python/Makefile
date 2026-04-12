ifndef PYTHON
	PYTHON=$(shell which python3)
endif

CFLAGS += -fPIC

all:
	$(PYTHON) setup.py build_ext --inplace

install:
	$(PYTHON) setup.py install --root=${DESTDIR} --install-layout=deb

clean:
	rm -rf build dparser.pyc dparser_swigc.* dparser_wrap.c swigpyrun.h \
		tests/d_parser_mach_gen.*

TEST_SCRIPTS = $(shell ls tests/test*.py)
test:
	@$(foreach test, $(TEST_SCRIPTS), \
		echo "    running test $(test)" && \
		PYTHONPATH="." $(PYTHON) $(test) && \
	) echo "All unit tests passed." || \
	( echo "At least one unit test failed."; exit 2 )

.PHONY: all test install clean
