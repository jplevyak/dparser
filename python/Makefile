ifndef PYTHON
	PYTHON=$(shell which python)
endif

all:
	swig  -python -external-runtime
	swig  -python dparser.i
	$(PYTHON) setup.py build

install:
	$(PYTHON) setup.py install --root=${DESTDIR} --install-layout=deb

clean:
	rm -rf build dparser.pyc dparser_swigc.* dparser_wrap.c swigpyrun.h \
		tests/d_parser_mach_gen.*

PYTHON_PLATLIB=$(shell $(PYTHON) -c "from distutils.command.build import build; from distutils.core import Distribution; b = build(Distribution()); b.finalize_options(); print(b.build_platlib)")

TEST_SCRIPTS = $(shell ls tests/test*.py)
test:
ifeq ($(wildcard $(PYTHON_PLATLIB)),)
	$(error "Unable to determine python platform library directory.")
endif
	@$(foreach test, $(TEST_SCRIPTS), \
		echo "    running test $(test)" && \
		PYTHONPATH="$(PYTHON_PLATLIB)" $(PYTHON) $(test) && \
	) echo "All unit tests passed." || \
	( echo "At least one unit test failed."; exit 2 )

.PHONY: all test install clean
