# Interior Designer — first usable floor stage

Open a saved town and create at least one exterior entrance on a building in **Building Creator**. Then choose **Interior designer** in the sidebar.

1. Choose the building.
2. Select **Create blank ground floor**. Creator Studio converts the actual OSM footprint to local metres. Concave edges and mapped courtyard holes are retained.
3. Optionally select **Add upper floor**. Each new floor starts with the same footprint shape.
4. Choose a floor and set its size from 100% to 300%, then select **Apply floor size**. This enlarges the full outline proportionally; it does not turn the floor into a rectangle. A size above 100% is saved as a creator adjustment, not a claim about the real building.
5. Choose an exterior entrance and select **Place selected entry point**. Creator Studio switches to the ground floor; click inside the usable floor area.
6. To place a storyline character indoors, choose the intended floor and select **Select and copy interior location**. Click a clear point. The blue crosshair records and copies the stable building ID, floor ID and local X/Y position in metres.
7. Select **Save interior layout**.

Paste the copied value into **NPCs and personas → Storyline NPCs**. It looks like `Interior: building=484843857; floor=ground_floor; x=8.50; y=4.25`. The creator checks that the building and floor still exist and that the point remains inside the usable floor rather than a wall/courtyard opening.

The canonical town file is `data/building_interiors.json`. Floors use stable IDs and remain attached to the stable OSM building ID. Create/Rebuild preserves this file. The format is documented by `schemas/building_interiors.schema.json` and can be validated without an LLM.

In **Play test**, walk to the green exterior arrow and press **E**. The player transfers to the saved ground-floor arrival point and may walk only inside the footprint-shaped floor; courtyard holes remain blocked. The ground floor is fully included and uses the stable `ground_floor` ID. Press **M** indoors to open a fitted map of the current floor. Moving the mouse changes the map crosshair and its building, floor and local X/Y metre readout without moving the player. **Copy location** places the standard one-line `Interior: building=…; floor=…; x=…; y=…` text on the Windows clipboard, ready for Notepad or Storyline NPC placement. These location details are hidden during normal play. An interior storyline NPC appears at its exact saved point only in its assigned building/floor, so a character placed far from the entrance may require walking through the interior before it becomes visible. It supports the same **T** conversation flow. Return to the green interior marker and press **E** to exit at the same exterior arrow.

This stage does not yet draw internal walls or rooms, place stairs/furniture, or provide travel between saved upper floors. A storyline NPC can be stored on an upper floor, but will not be reachable in gameplay until stairs/floor travel are implemented.
