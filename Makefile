.PHONY: all html build

all: build

build:
	python setup.py build_ext --inplace --force

html:
	-rm -rf docs/build
	make -C docs html
