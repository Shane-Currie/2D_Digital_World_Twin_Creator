# Traffic behaviour

Creator v1.3 uses each imported town's generated OSM vehicle graph. The runtime does not require an LLM or town-specific coordinates.

## Intersection rules

- Cars retain a safe following distance on ordinary road segments.
- A moving queue may share an intersection when every car has the same entry and planned exit and the leader has opened a safe gap.
- Opposing straight-through movements may proceed together. Their visible left/right lane offsets keep them on separate sides of the road.
- A turn or merge that conflicts with an existing movement waits outside the intersection.
- A car does not enter when a stationary vehicle blocks its planned exit.
- A reservation remains active until the vehicle has travelled clear of the junction. Reaching the centre point is not sufficient.
- Once committed, a car clears the junction if the traffic light changes instead of stopping inside it.
- Simultaneous conflicting arrivals use waiting time and a stable traffic ID to prevent frame-order uncertainty. This is a conservative fallback where OSM has no detailed priority or lane-turn data.

## Imported controls and recovery

OSM traffic-signal and stop nodes retain the existing simple two-axis signal cycle and one-second stop. Local council timings are normally absent from OSM and are not guessed. Legal red/amber and pedestrian-crossing waits remain exempt from jam relocation. Other blocked traffic can use the configured distant relocation fallback after the saved timeout.

## Current limits

OSM commonly omits controller timing, individual turn lanes and lane-to-lane connectors. v1.3 therefore plans one outgoing graph edge ahead and applies conservative conflict rules. It does not claim surveyed signal phases, advanced roundabout lane selection or a complete microscopic traffic simulation. Extended congestion and performance testing remains with the user.
