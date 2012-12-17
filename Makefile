.PHONY: all html build

all: build

build:
	python setup.py build_ext --inplace --force

html: build
	-rm -rf docs/build
	env PYTHONPATH=$(shell pwd) make -C docs html
