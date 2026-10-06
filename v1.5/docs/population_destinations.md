# Population destinations

NPCs and NPR robots no longer choose only a random adjacent path. Creator Studio builds `data/population_destinations.json` from the uploaded town and the generated pedestrian graph, then the runtime plans trips between reachable mapped places.

## What becomes a destination

Only OSM use tags attached directly to a building footprint are used. Supported groups are residential, education, health, retail, office, hospitality, civic, recreation, industrial and transport. An unclassified `building=yes` footprint is not assigned a use. A nearby point of interest is not promoted to the whole building, because one footprint may contain several tenants.

Each record keeps its footprint ID, mapped or neutral name, category source tag, **© OpenStreetMap contributors** attribution and nearest pedestrian-node link. The link must be within 250 metres. It is a routing connection, not a claim that an exact door or entrance was mapped; `entrance_status` remains `not_mapped_or_not_selected`.

## Runtime behaviour

- NPCs receive a reachable residential home when one exists, travel to a reachable non-residential activity, pause there, and alternate back toward home.
- NPR robots travel between reachable non-residential service/activity places. They use the same footpath, building/water avoidance and road-crossing safety rules as NPCs.
- Destination selection is restricted to the actor's connected pedestrian-network section. A river, motorway or incomplete OSM path cannot cause repeated impossible route requests to another disconnected section.
- If the map contains no usable tagged places, the existing graph wandering remains as a safe fallback. No LLM, town-specific coordinates or invented building uses are used.

This stage provides map-derived travel demand, not schedules, jobs, shopping transactions, interior entry or exact door approach paths. Those require later creator and interior stages. Rebuild an older town to save its destination file; the runtime can derive the same information in memory until then.

Focused verification covers direct tag classification, truthful unknown buildings, the 250-metre link limit, graph route planning, NPC/NPR assignment and disconnected-network filtering. The Albury test generated 257 usable destinations across eight categories, including 116 residential and 141 activity places; 167 of 170 NPCs/NPRs received reachable destination travel and the three walkers in sections without a destination retained safe graph wandering. Extended behaviour and performance on other uploaded maps remain user-tested.
