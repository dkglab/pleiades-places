.PHONY: clean

clean:
	rm -f pleiades-places.csv

pleiades-places.csv: data/pleiades_places/pleiades_places.shp
	ogr2ogr \
	-f CSV \
	-lco GEOMETRY=AS_WKT \
	$@ $<
