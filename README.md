# pleiades-places

Builds `pleiades-places.nt`, an N-Triples version of the [Pleiades](https://pleiades.stoa.org/) gazetteer that follows the [Linked Art Place model](https://linked.art/model/place/), using CIDOC-CRM where Linked Art has nothing suitable.

## Usage

```sh
make            # build pleiades-places.nt
make examples   # regenerate the example places in examples/ and their diagrams
make diagrams   # regenerate only the diagrams of the examples
make clean      # remove the output and intermediate files
make superclean # also remove downloaded data and tools
```

Requirements: GNU make, bash, curl, jq (1.7 or later), GNU coreutils and Java 21 or later. The diagrams also need Python 3 and [Graphviz](https://graphviz.org/). The Makefile downloads [Apache Jena](https://jena.apache.org/) and [SPARQL Anything](https://sparql-anything.cc/) into `tools/`, and installs [RDFLib](https://rdflib.readthedocs.io/) in a virtual environment there for [`scripts/diagram.py`](scripts/diagram.py), which draws the diagrams with `rdf2dot`.

## How the build works

1. **Download** the latest Pleiades JSON dump (about 1.9 GB uncompressed) and the place-type vocabulary into `data/`.
2. **Stream** the dump through [`queries/records.jq`](queries/records.jq) with `jq --stream`, so only one place is in memory at a time. This writes one compact record per published place to `data/places.jsonl`, and along the way:
   - keeps only published names and locations
   - converts GeoJSON to WKT
   - takes each location's precision (`precise`, `rough` or `unlocated`) from the dump's `features`
   - splits romanized names into separate forms
3. **Construct** RDF: split the records into chunks of 2,000 places and run [`queries/construct.rq`](queries/construct.rq) on each chunk with SPARQL Anything, writing N-Triples. [`queries/place-types.rq`](queries/place-types.rq) adds labels for the place types.
4. **Merge** the chunks with `LC_ALL=C sort -u`, which also removes duplicate triples. The `C` locale matters: other locales ignore hyphens when comparing and silently drop distinct lines.
5. **Check** the output: `riot --validate` parses it, and the build fails if it contains no places.

Chunking and the 4 GB Java heap cap (`-Xmx4g`) keep a full build within 8 GB of RAM. It takes about 8 minutes.

## Model

| Pleiades | RDF |
|---|---|
| place | `crm:E53_Place` with `rdfs:label`, place types (`crm:P2_has_type`) and a representative point (`crm:P168_place_is_defined_by`) |
| name | one `crm:E33_E41_Linguistic_Appellation` per attested or romanized form, linked with `crm:P1_is_identified_by` |
| description, details | `crm:E33_Linguistic_Object`, linked with `crm:P67i_is_referred_to_by` |
| location | its own `crm:E53_Place` with a WKT geometry (`geo:wktLiteral`). The ancient place `crm:P89_falls_within` a rough location; any other location `crm:P189_approximates` the ancient place. |

Pleiades URIs are used as-is for places, locations, names and vocabulary terms. See [`examples/`](examples/) for four places in Turtle. Open modelling questions are tracked in the [issues](https://github.com/dkglab/pleiades-places/issues).

## CI

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs `make` on every pull request and uploads `pleiades-places.nt` as an artifact.
