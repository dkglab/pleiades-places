"""Draw a Turtle file as a Graphviz DOT diagram, using rdflib's rdf2dot.

Before drawing, shorten long literals and show each resource's types in
its own box rather than as edges to shared class nodes, which otherwise
make the diagram too wide to read.
"""

import io
import re
import sys

from rdflib import RDF, Graph, Literal
from rdflib.tools.rdf2dot import rdf2dot

MAX_LITERAL = 50

source = Graph().parse(sys.argv[1], format="turtle")
graph = Graph()
graph.namespace_manager = source.namespace_manager

for s, p, o in source:
    if p == RDF.type:
        o = Literal(source.namespace_manager.normalizeUri(o))
    elif isinstance(o, Literal) and len(o) > MAX_LITERAL:
        o = Literal(o[:MAX_LITERAL] + "…", lang=o.language, datatype=o.datatype)
    graph.add((s, p, o))

dot = io.StringIO()
rdf2dot(graph, dot)

# Types are names, not strings, so drop the quotes rdf2dot puts around them.
sys.stdout.write(
    re.sub(
        r"(<td align='left'>rdf:type</td><td align='left'>)&quot;(.*?)&quot;",
        r"\1\2",
        dot.getvalue(),
    )
)
