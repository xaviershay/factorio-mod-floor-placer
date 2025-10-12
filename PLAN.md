# Rate-Limited Tile Placement Plan

## Issue
[#10 - Placing huge amounts of tiles takes a loooong time](https://github.com/xaviershay/factorio-mod-floor-placer/issues/10)

When selecting a large area (especially from zoomed-out map view), the mod processes all tiles synchronously in a single tick, which causes the game to hang/freeze.

## Solution Overview
Implement rate-limited tile placement that spreads the work across multiple ticks, processing only `max_tiles_per_tick` tiles per tick.

## Architecture

### Data Structures

#### New storage variables:
- `storage.placement_queue` - Array of pending placement jobs
  - Each entry: `{ area, tile_name, surface, force, player, offset }`
  - `area` - The bounding box selected by the player
  - `tile_name` - The tile prototype name to place
  - `surface` - The surface to place tiles on
  - `force` - The force placing the tiles
  - `player` - The player placing the tiles
  - `offset` - Number of tiles already processed (0-indexed)

- `storage.tick_handler_registered` - Boolean flag tracking whether the on_tick handler is active

#### New configuration:
- `max_tiles_per_tick` - Setting controlling how many tiles to process per tick
  - Default: 100 (to be tuned based on testing)
  - Consider making this a mod setting later

### Control Flow

#### 1. Selection Handler (`on_player_selected_area`)
**Current behavior:** Processes entire area synchronously

**New behavior:**
1. Calculate total tiles in selected area
2. If total <= `max_tiles_per_tick`, process immediately (fast path)
3. Otherwise:
   - Create placement job: `{ area, tile_name, surface, force, player, offset = 0 }`
   - Push to back of `storage.placement_queue`
   - Register tick handler if not already registered

#### 2. Tick Handler (`on_tick`)
**Behavior:**
1. Check if `storage.placement_queue` is empty
   - If empty: deregister handler, set `storage.tick_handler_registered = false`, return
2. Get first (oldest) job from front of queue
3. Calculate which tiles to process this tick:
   - Start tile index = `job.offset`
   - End tile index = `job.offset + max_tiles_per_tick - 1`
   - Convert indices to (x,y) coordinates within the area
4. Process the calculated tiles (reuse existing tile placement logic)
5. Update `job.offset` by tiles processed (ensure that it is updated in the queue, not just locally)
6. Check if job complete:
   - Calculate total tiles in job area
   - If `job.offset >= total_tiles`: remove job from queue (shift array)
   - Otherwise: job stays at front of queue for next tick

#### 3. Helper Functions

##### `calculate_total_tiles(area)`
- Returns: `(width) * (height)` where width/height are derived from area bounds

##### `get_tile_coords_for_offset(area, offset)`
- Converts linear offset to (x, y) coordinate
- Returns: `{ x, y }` position

##### `get_tiles_to_process_this_tick(job, max_tiles)`
- Calculates which tiles should be processed this tick
- Iterates from `job.offset` to `min(job.offset + max_tiles, total_tiles)`
- Converts each offset to (x,y) using `get_tile_coords_for_offset`
- Returns: Array of coordinates `{ {x=x1, y=y1}, {x=x2, y=y2}, ... }`
- Example: `{ {x=10, y=5}, {x=11, y=5}, {x=12, y=5}, ... }` (up to max_tiles entries)

##### `process_tile_placement(x, y, tile_name, surface, force, player)` (extracted)
- Refactor existing tile placement logic from double-loop
- Handles single tile: collision checks, ghost placement, etc.
- Returns: nothing (void)

### Algorithm: Linear Index to 2D Coordinates

Given an area with bounds `[left, right)` x `[top, bottom)`:
- Width = `ceil(area.right_bottom.x) - floor(area.left_top.x)`
- Height = `ceil(area.right_bottom.y) - floor(area.left_top.y)`
- For offset `n`:
  - `x = floor(area.left_top.x) + (n % width)`
  - `y = floor(area.left_top.y) + floor(n / width)`

This allows us to process tiles row-by-row (left-to-right, top-to-bottom).

## Implementation Steps

### Phase 1: Refactoring ✅ DONE
1. ✅ Extract tile placement logic from `process_selected_area_with_this_mod` into `process_tile_placement(x, y, ...)`
2. ✅ Add helper function `calculate_total_tiles(area)`
3. ✅ Add helper function `get_tile_coords_for_offset(area, offset)`
4. Test that nothing breaks (existing synchronous behavior should still work)

### Phase 2: Queue Infrastructure
1. Initialize `storage.placement_queue` as empty array
2. Initialize `storage.tick_handler_registered = false`
3. Add tick handler registration/deregistration functions
4. Create `get_tiles_to_process_this_tick(job, max_tiles)` helper

### Phase 3: Async Processing
1. Modify `process_selected_area_with_this_mod`:
   - Add size check (fast path vs queue path)
   - Create and enqueue jobs for large areas
   - Register tick handler
2. Implement tick handler logic:
   - Dequeue first job
   - Process batch of tiles
   - Update offset or remove job
   - Deregister when queue empty

### Phase 4: Configuration & Polish
1. Define `max_tiles_per_tick` constant (start with 100)
2. Add comments explaining the rate limiting
3. Test with various area sizes
4. Consider adding visual feedback (progress indicator?) - future enhancement

## Testing Checklist

- [ ] Small area (< max_tiles_per_tick) - should work instantly as before
- [ ] Medium area (2-3x max_tiles_per_tick) - should complete over 2-3 ticks
- [ ] Large area (1000+ tiles) - should not freeze game
- [ ] Multiple selections in quick succession - should queue properly
- [ ] Edge cases:
  - [ ] Area with ungenerated chunks
  - [ ] Area with existing tile ghosts
  - [ ] Area with mixed water/ground tiles
  - [ ] Area on foundation vs non-foundation

## Performance Considerations

1. **Tile budget**: Start with 100 tiles/tick, tune based on testing
   - Too high: still causes lag
   - Too low: placement feels sluggish
   
2. **Memory**: Queue should be bounded by player actions (unlikely to have hundreds of pending jobs)

3. **Edge case**: If player logs out with pending jobs, jobs should be cleaned up or persist correctly

## Future Enhancements (Out of Scope)

- Make `max_tiles_per_tick` a mod setting

## Notes

- Existing synchronous behavior is preserved for small selections (no regression)
- Tick handler only runs when there's work to do (efficient)
- FIFO queue ensures fairness when multiple areas selected
- Offset-based tracking allows resuming from any point
