# Turn the Pleiades JSON dump into one compact JSON record per published place.
#
# Run with: jq -cn --stream -f queries/records.jq pleiades-places-latest.json
#
# The dump is streamed, so only one place is held in memory at a time.

# Drop null and empty-string fields so the CONSTRUCT can test them with OPTIONAL.
def compact: with_entries(select(.value != null and .value != ""));

def published: select(.review_state == "published");

# A usable RDF language tag, or null. Drops "None" and values that are not
# well-formed BCP 47 (e.g. "etruscan-in-latin-characters").
def language_tag:
  if . == null or . == "None" then null
  elif test("^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*$") then .
  else null
  end;

# GeoJSON -> WKT. Coordinates stay longitude-first; any Z value is dropped.
def wkt_position: "\(.[0]) \(.[1])";
def wkt_positions: "(" + (map(wkt_position) | join(", ")) + ")";
def wkt_rings: "(" + (map(wkt_positions) | join(", ")) + ")";
def wkt_polygons: "(" + (map(wkt_rings) | join(", ")) + ")";
def wkt:
  if . == null then null
  elif .type == "Point" then "POINT (\(.coordinates | wkt_position))"
  elif .type == "LineString" then "LINESTRING \(.coordinates | wkt_positions)"
  elif .type == "Polygon" then "POLYGON \(.coordinates | wkt_rings)"
  elif .type == "MultiPoint" then "MULTIPOINT \(.coordinates | wkt_positions)"
  elif .type == "MultiLineString" then "MULTILINESTRING \(.coordinates | wkt_rings)"
  elif .type == "MultiPolygon" then "MULTIPOLYGON \(.coordinates | wkt_polygons)"
  else error("unsupported geometry type: \(.type)")
  end;

fromstream(2 | truncate_stream(inputs | select(.[0][0] == "@graph")))
| published
# location_precision (precise, rough or unlocated) is only given in the
# GeoJSON features, which are keyed by location URI.
| (.features | map({key: .properties.link, value: .properties.location_precision})
  | from_entries) as $precision
| {
    uri,
    title,
    description,
    details,
    placeTypeURIs,
    reprPoint: (if .reprPoint then {type: "Point", coordinates: .reprPoint} | wkt else null end),
    # One record per name form: the attested form (language-tagged) and each
    # comma-separated romanized form (untagged).
    appellations: [
      .names[] | published | .uri as $uri | .nameType as $type
      | ((select(.attested != "" and .attested != null)
          | {uri: "\($uri)#attested", nameType: $type, content: .attested, language: (.language | language_tag)}),
         (.romanized // "" | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))
          | to_entries[]
          | {uri: "\($uri)#romanized-\(.key + 1)", nameType: $type, content: .value}))
      | compact
    ],
    locations: [
      .locations[] | published
      | {
          uri,
          title,
          precision: $precision[.uri],
          wkt: (.geometry | wkt),
          # Normalize "associated modern" and drop the trailing "".
          locationTypes: [.locationType[]? | gsub(" "; "_") | select(. != "")] | unique,
          accuracy,
          accuracy_value
        }
      | compact
    ],
    connections: [.connections[] | published | {connectsTo, connectionType} | compact]
  }
| compact
