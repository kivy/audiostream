.PHONY: all html build

all: build

build:
	python setup.py build_ext --inplace --force

html: build
	-rm -rf docs/build
	make -C docs html
