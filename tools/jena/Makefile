SHELL := /usr/bin/env bash
.SHELLFLAGS := -O extglob -o pipefail -c
.DELETE_ON_ERROR:

TOOLS := curl tar

X := $(foreach tool,$(TOOLS),\
	$(if $(shell which $(tool)),,\
	$(error Please install $(tool) and ensure it is in your path)))

JENA_HOST := https://archive.apache.org/dist/jena/binaries
JENA_VERSION := 6.2.0

.PHONY: all clean

all: bin/riot

clean:
	rm -rf !(Makefile)

bin/riot:
	curl -fsSL $(JENA_HOST)/apache-jena-$(JENA_VERSION).tar.gz \
	| tar -zxf - --strip-components 1
