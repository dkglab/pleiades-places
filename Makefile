SHELL := /usr/bin/env bash
.SHELLFLAGS := -O extglob -c

SPARQL-ANY := ./tools/sparql-anything/sparql-anything.jar
ARQ := ./tools/jena/bin/arq
RIOT := ./tools/jena/bin/riot

.PHONY: all clean superclean

PLEIADES := https://atlantides.org/downloads/pleiades

define green
\033[0;32m$(1)\033[0m
endef

define red
\033[0;31m$(1)\033[0m
endef

define log
	@echo "\\n$(call green,$(1))"
endef

all: pleiades-places.ttl pleiades-places.nt

clean:
	rm -f pleiades-places.ttl

superclean: clean
	rm -f data/pleiades-places-latest.json* data/place-types.ttl
	$(MAKE) -s -C tools/sparql-anything clean
	$(MAKE) -s -C tools/jena clean

$(ARQ) $(RIOT):
	@$(MAKE) -s -C tools/jena

$(SPARQL-ANY):
	$(MAKE) -s -C tools/sparql-anything

data/pleiades-places-latest.json:
	curl $(PLEIADES)/json/pleiades-places-latest.json.gz > data/pleiades-places-latest.json.gz
	gunzip -f data/pleiades-places-latest.json.gz
	touch $@

data/place-types.ttl:
	curl $(PLEIADES)/rdf/place-types.ttl \
	| sed 's|//pleiades.stoa.org/vocabularies/|//pleiades.stoa.org/vocabularies/place-types/|g' \
	> $@

pleiades-places.ttl: \
	queries/construct.rq queries/count.rq \
	data/pleiades-places-latest.json data/place-types.ttl \
	| $(SPARQL-ANY) $(ARQ)
	java -Xmx24g -jar $(SPARQL-ANY) -q $< > $@
	$(call log,Counting resources in $@ using $(word 2,$^))
	@echo $(ARQ) --data $@ --query $(word 2,$^)
	@count=$$($(ARQ) --data $@ --query $(word 2,$^) --results csv | tail -n 1 | tr -d '\r\n') ; \
	[ "$$count" -gt 0 ] && \
	{ echo "$(call green,$$count resources constructed)" ; } || \
	{ echo "$(call red,No resources found in $@!)" ; exit 1 ; }

pleiades-places.nt: pleiades-places.ttl
	$(RIOT) --quiet --output=ntriples $< \
	2> >(rg -v 'WARN  riot' 1>&2) > $@ || true
