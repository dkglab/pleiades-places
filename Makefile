SPARQL-ANY := tools/sparql-anything/sparql-anything.jar

.PHONY: all clean superclean

PLEIADES := https://atlantides.org/downloads/pleiades

all: pleiades-places.ttl

clean:
	rm -f pleiades-places.ttl data/pleiades-places.csv data/pleiades-places-latest.json*

superclean: clean
	$(MAKE) -s -C tools/sparql-anything clean

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
	pleiades-places.rq \
	data/pleiades-places.csv data/pleiades-places-latest.json \
	| $(SPARQL-ANY)
	java -Xmx24g -jar $(SPARQL-ANY) -q $< > $@
