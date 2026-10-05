SHELL := /usr/bin/env bash
.SHELLFLAGS := -O extglob -o pipefail -c
.DELETE_ON_ERROR:
SA_HOST := https://github.com/SPARQL-Anything/sparql.anything/releases/download
SA_VERSION := v1.2.0

.PHONY: all clean

all: sparql-anything.jar

clean:
	rm -rf !(Makefile)

sparql-anything.jar:
	curl -fsSL $(SA_HOST)/$(SA_VERSION)/sparql-anything-$(SA_VERSION).jar > $@
