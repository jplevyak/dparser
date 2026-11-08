ifndef PYTHON
	PYTHON=$(shell which python3)
endif

all:
	cd .. && $(PYTHON) setup.py build_ext --inplace

install:
	cd .. && $(PYTHON) -m pip install --no-deps $(if $(DESTDIR),--root=$(DESTDIR)) .

clean:
	rm -rf dparser.c dparser.h dparser*.so \
		d_parser_mach_gen.g*

test: all
	PYTHONPATH=. $(PYTHON) -m pytest tests

.PHONY: all test install clean
