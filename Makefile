.PHONY: clean

PLEIADES := https://atlantides.org/downloads/pleiades

clean:
	rm -f pleiades-places.csv

pleiades-places.csv: data/awmc-pleiades-shapefiles/pleiades_places.shp
	ogr2ogr \
	-f CSV \
	-lco GEOMETRY=AS_WKT \
	$@ $<

data/pleiades-places-latest.json.gz:
	curl $(PLEIADES)/json/pleiades-places-latest.json.gz > $@

data/pleiades-places-latest.json: data/pleiades-places-latest.json.gz
	gunzip -f $<

