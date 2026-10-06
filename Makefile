SHELL := /usr/bin/env bash
.SHELLFLAGS := -O extglob -o pipefail -c
.DELETE_ON_ERROR:

SPARQL-ANY := ./tools/sparql-anything/sparql-anything.jar
RIOT := ./tools/jena/bin/riot
# Keep the heap well below the sprite's 8 GB so that running out of memory
# is a Java OutOfMemoryError rather than a crashed machine.
JAVA := java -Xmx4g
CHUNK_SIZE := 2000

.PHONY: all clean superclean examples

PLEIADES := https://atlantides.org/downloads/pleiades

# Example places, chosen to show a range of modelling choices
# (see examples/README.md).
EXAMPLES := phaleron epidion-akron ichthyophagoi althaia-cartala
examples/phaleron.ttl: PLACE := 580072
examples/epidion-akron.ttl: PLACE := 89178
examples/ichthyophagoi.ttl: PLACE := 29605
examples/althaia-cartala.ttl: PLACE := 270296

define PREFIXES
@prefix aat: <http://vocab.getty.edu/aat/> .
@prefix crm: <http://www.cidoc-crm.org/cidoc-crm/> .
@prefix geo: <http://www.opengis.net/ont/geosparql#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix location-types: <https://pleiades.stoa.org/vocabularies/location-types/> .
@prefix name-types: <https://pleiades.stoa.org/vocabularies/name-types/> .
@prefix place-types: <https://pleiades.stoa.org/vocabularies/place-types/> .
endef
export PREFIXES

define green
\033[0;32m$(1)\033[0m
endef

define red
\033[0;31m$(1)\033[0m
endef

define log
	@echo -e "\\n$(call green,$(1))"
endef

all: pleiades-places.nt

clean:
	rm -rf pleiades-places.nt data/places.jsonl data/chunks

superclean: clean
	rm -f data/pleiades-places-latest.json* data/place-types.ttl
	$(MAKE) -s -C tools/sparql-anything clean
	$(MAKE) -s -C tools/jena clean

examples: $(EXAMPLES:%=examples/%.ttl)

# Everything said about a place, its names, statements and locations, plus
# the vocabulary terms they use.
examples/%.ttl: pleiades-places.nt | $(RIOT)
	mkdir -p examples
	grep -E '^<https://pleiades\.stoa\.org/places/$(PLACE)[>/#]' $< > $@.nt
	grep -oE '<https://pleiades\.stoa\.org/vocabularies/[^>]+>' $@.nt \
	| sort -u | awk 'NR == FNR { terms[$$0] ; next } $$1 in terms' - $< >> $@.nt
	{ echo "$$PREFIXES" ; cat $@.nt ; } | $(RIOT) --syntax=ttl --formatted=ttl - > $@
	rm $@.nt

$(RIOT):
	@$(MAKE) -s -C tools/jena

$(SPARQL-ANY):
	$(MAKE) -s -C tools/sparql-anything

data/pleiades-places-latest.json:
	mkdir -p data
	curl -fsSL $(PLEIADES)/json/pleiades-places-latest.json.gz > data/pleiades-places-latest.json.gz
	gunzip -f data/pleiades-places-latest.json.gz
	touch $@

data/place-types.ttl:
	mkdir -p data
	curl -fsSL $(PLEIADES)/rdf/place-types.ttl \
	| sed 's|//pleiades.stoa.org/vocabularies/|//pleiades.stoa.org/vocabularies/place-types/|g' \
	> $@

# Stream the dump into one compact record per published place.
data/places.jsonl: queries/records.jq data/pleiades-places-latest.json
	$(call log,Streaming published places from $(word 2,$^))
	jq -cn --stream -f $^ > $@.tmp
	mv $@.tmp $@

# Run the CONSTRUCT on chunks of CHUNK_SIZE places, so that SPARQL Anything
# never has to hold the whole dump in memory, then merge the chunks.
pleiades-places.nt: \
	queries/construct.rq queries/place-types.rq \
	data/places.jsonl data/place-types.ttl \
	| $(SPARQL-ANY) $(RIOT)
	rm -rf data/chunks
	mkdir -p data/chunks
	split -l $(CHUNK_SIZE) -d -a 3 --additional-suffix=.jsonl \
	$(word 3,$^) data/chunks/places-
	$(call log,Constructing triples for $$(ls data/chunks/*.jsonl | wc -l) chunks)
	@set -eo pipefail ; for chunk in data/chunks/*.jsonl ; do \
	echo "$$chunk" ; \
	jq -s . "$$chunk" > "$${chunk%l}" ; \
	$(JAVA) -jar $(SPARQL-ANY) -q $< -c location="$${chunk%l}" -f NT \
	-o "$${chunk%.jsonl}.nt" 2> >(grep -v 'Options passed with -c' 1>&2) ; \
	done
	$(JAVA) -jar $(SPARQL-ANY) -q $(word 2,$^) -f NT -o data/chunks/place-types.nt
	LC_ALL=C sort -u data/chunks/*.nt > $@
	$(call log,Validating $@)
	$(RIOT) --validate $@
	$(call log,Counting places in $@)
	@count=$$(grep -c '> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.cidoc-crm.org/cidoc-crm/E53_Place> \.$$' $@) ; \
	[ "$$count" -gt 0 ] && \
	{ echo -e "$(call green,$$count places (including locations) in $$(wc -l < $@) triples)" ; } || \
	{ echo -e "$(call red,No places found in $@!)" ; exit 1 ; }
