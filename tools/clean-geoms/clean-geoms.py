import sys
import json
from rdflib import Graph, Literal, Namespace, URIRef
from geomet import wkt

PLEIADES = Namespace("https://pleiades.stoa.org/places/vocab#")
OSGEO = Namespace("http://data.ordnancesurvey.co.uk/ontology/geometry/")
GEO = Namespace("http://www.opengis.net/ont/geosparql#")


def replace_statements(g: Graph, old_p: URIRef, new_p: URIRef):
    for s, p, geojson_literal in g.triples((None, old_p, None)):
        geojson = json.loads(str(geojson_literal))
        if geojson is not None:
            g.add(
                (
                    s,
                    new_p,
                    Literal(wkt.dumps(geojson), datatype=GEO.wktLiteral),
                )
            )
        g.remove((s, p, geojson_literal))


def main(arguments: list[str]) -> int:
    try:
        g = Graph()
        g.bind("pleiades", PLEIADES)
        g.bind("osgeo", OSGEO)
        g.bind("geo", GEO)
        g.parse(arguments[0])
        replace_statements(g, OSGEO.asGeoJSON, OSGEO.asWKT)
        replace_statements(
            g, PLEIADES.hasRepresentativePoint, PLEIADES.hasRepresentativePoint
        )
        print(g.serialize(format="turtle"))
        return 0
    except Exception as e:
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    arguments = sys.argv[1:]
    code = main(arguments)
    sys.exit(code)
