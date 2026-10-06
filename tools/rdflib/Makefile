SHELL := /usr/bin/env bash
.SHELLFLAGS := -O extglob -o pipefail -c
.DELETE_ON_ERROR:

TOOLS := python3

X := $(foreach tool,$(TOOLS),\
	$(if $(shell which $(tool)),,\
	$(error Please install $(tool) and ensure it is in your path)))

RDFLIB_VERSION := 7.6.0

.PHONY: all clean

all: bin/rdf2dot

clean:
	rm -rf !(Makefile)

bin/rdf2dot:
	python3 -m venv .
	./bin/pip install -q --disable-pip-version-check rdflib==$(RDFLIB_VERSION)
