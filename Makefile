SPARQL-ANY := tools/sparql-anything/sparql-anything.jar
ARQ := ./tools/jena/bin/arq

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

all: pleiades-places.ttl

clean:
	rm -f pleiades-places.ttl

superclean: clean
	rm -f data/pleiades-places.csv data/pleiades-places-latest.json*
	$(MAKE) -s -C tools/sparql-anything clean
	$(MAKE) -s -C tools/jena clean

$(ARQ):
	@$(MAKE) -s -C tools/jena

$(SPARQL-ANY):
	$(MAKE) -s -C tools/sparql-anything

data/pleiades-places.csv: data/awmc-pleiades-shapefiles/pleiades_places.shp
	ogr2ogr \
	-f CSV \
	-lco GEOMETRY=AS_WKT \
	$@ $<

data/pleiades-places-latest.json:
	curl -O $(PLEIADES)/json/$@.gz
	gunzip -f $@.gz
	touch $@

pleiades-places.ttl: \
	queries/construct.rq queries/count.rq \
	data/pleiades-places-latest.json \
	| $(SPARQL-ANY) $(ARQ)
	java -Xmx24g -jar $(SPARQL-ANY) -q $< > $@ 2> /dev/null
	$(call log,Counting resources in $@ using $(word 2,$^))
	@echo $(ARQ) --data $@ --query $(word 2,$^)
	@count=$$($(ARQ) --data $@ --query $(word 2,$^) --results csv | tail -n 1 | tr -d '\r\n') ; \
	[ "$$count" -gt 0 ] && \
	{ echo "$(call green,$$count resources constructed)" ; } || \
	{ echo "$(call red,No resources found in $@!)" ; exit 1 ; }
