ifndef PYTHON
	PYTHON=$(shell which python3)
endif

CFLAGS += -fPIC

all:
	swig  -python -external-runtime
	swig  -python dparser.i
	$(PYTHON) setup.py build

install:
	$(PYTHON) setup.py install --root=${DESTDIR} --install-layout=deb

clean:
	rm -rf build dparser.pyc dparser_swigc.* dparser_wrap.c swigpyrun.h \
		tests/d_parser_mach_gen.*

TEST_SCRIPTS = $(shell ls tests/test*.py)
test:
	@PLATLIB=$$($(PYTHON) -c "import glob, sysconfig, os; print(next((d for d in glob.glob('build/lib.*') if os.path.exists(os.path.join(d, '_dparser_swigc' + sysconfig.get_config_var('EXT_SUFFIX')))), ''))"); \
	if [ -z "$$PLATLIB" ]; then echo "Unable to determine python platform library directory."; exit 1; fi; \
	$(foreach test, $(TEST_SCRIPTS), \
		echo "    running test $(test)" && \
		PYTHONPATH="$$PLATLIB" $(PYTHON) $(test) && \
	) echo "All unit tests passed." || \
	( echo "At least one unit test failed."; exit 2 )

.PHONY: all test install clean
