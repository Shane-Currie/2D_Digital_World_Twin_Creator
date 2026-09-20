# Player controls

## Walking

- **W** — walk up/north
- **S** — walk down/south
- **A** — walk left/west
- **D** — walk right/east
- **E** — enter the wagon when close enough, or exit after stopping
- **M** — open or close the town map
- **F11** — toggle full screen

Walking is four-directional and world-aligned. The camera does not rotate. When horizontal and vertical movement keys are held together, horizontal movement takes priority.

## Driving

- **Up Arrow** — raise the selected cruise speed by 1 km/h
- **Down Arrow** — lower the selected cruise speed by 1 km/h
- **Left/Right Arrow** — steer
- **Shift** — switch between Drive and Reverse after slowing to 2 km/h or less
- **Space** — emergency brake
- **E** — exit after the wagon has stopped and a safe space is available

Tap Up/Down for precise 1 km/h changes or hold them to use normal keyboard repeat. In either gear, the wagon automatically approaches and maintains the selected speed. Changing gear resets the target to zero. The analog speedometer has numbered ticks, a needle for actual speed, and the selected cruise speed in the centre. It also shows the gear and that gear's maximum.

Down Arrow cannot lower the target below zero and does not automatically engage Reverse. Space cancels the selected cruise speed and brakes immediately. A collision, invalid ground or leaving the wagon also resets the cruise target to zero. Reverse defaults to a 20 km/h maximum and can be changed in Game Settings.

New towns default to **200 km/h**. Creators can change **Maximum driving speed** from Game Settings without editing code. `max_speed_kmh` is converted to world movement using the generated town's `pixels_per_metre`, and the HUD converts that same world speed back to km/h. This keeps the displayed and physical maximum consistent across maps with different scales.

Forward acceleration defaults to **7.2 seconds from 0 to 100 km/h**. Creators can change **0–100 km/h acceleration time** in Game Settings. This replaces the old internal acceleration-unit control for driving feel; older saved towns use the 7.2-second default until changed.

The panel below the speedometer shows the wagon's lifetime **ODO** distance and resettable **TRIP A** distance only while you are in the car. Click **RESET** with the mouse whenever seated in the car, including while driving or viewing the map; there is no need to stop. It clears only Trip A and never changes the lifetime total or the car's speed. The panel is hidden on foot. Distance comes from the wagon's actual movement, converted with the imported town's map scale. The readings are saved in the town project's `saves/vehicle_odometer.json` (and a `.bak` copy), so they survive closing the game and rebuilding the town. An unreadable save is left untouched and reported instead of silently replacing lifetime mileage with zero.
