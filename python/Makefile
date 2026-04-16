ifndef PYTHON
	PYTHON=$(shell which python3)
endif

CFLAGS += -fPIC

all:
	$(PYTHON) setup.py build_ext --inplace

install:
	@INSTALL_FLAGS="--root=${DESTDIR}"; \
	if $(PYTHON) setup.py install --help 2>/dev/null | grep -q "install-layout"; then \
		INSTALL_FLAGS="$$INSTALL_FLAGS --install-layout=deb"; \
	fi; \
	$(PYTHON) setup.py install $$INSTALL_FLAGS

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
