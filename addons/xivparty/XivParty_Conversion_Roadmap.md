# XivParty (Windower to Ashita v4) Conversion Roadmap

**Objective:** Port the Lua-based `XivParty` addon from Windower 4 to Ashita v4.
**Target Architecture:** Ashita v4 Addon (Lua)
**Rationale:** The addon relies on UI rendering and game state reading, which is best handled by Ashita's Lua engine (ALE) rather than a C++ plugin.

**Sources:**
Original repository, targeting Windower: https://github.com/Tylas11/XivParty
Here is the ashita website: https://docs.ashitaxi.com/
Here are some example links see how addon development for ashita v4 works:
https://github.com/AshitaXI/example
https://github.com/AshitaXI/sdktest
https://github.com/AshitaXI/Ashita-v4beta/tree/main/addons
This person has written a bunch of plugins and addons for ashita v4: https://github.com/ThornyFFXI?tab=repositories

Please carefully review these sources, and clearly understand what an addon vs a plugin is.

Every time we are ready to test, we need to copy the addon to C:\dev\Ashita-v4beta\addons to test. It should be under it's own folder call xivparty.
---

## Milestone 1: The Skeleton & Environment
**Goal:** Establish the addon structure so Ashita recognizes, loads, and unloads it without errors.

### Tasks
- [x] **Create Directory:** Create folder `Ashita/addons/xivparty/`.
- [x] **Manifest:** ~~Create `addon.json`.~~ **UPDATE:** Ashita v4 uses inline metadata in the Lua file, not addon.json.
    - *Note:* Declare `addon.name`, `addon.author`, `addon.version`, `addon.desc` at top of main script.
- [x] **Entry Point:** Create `xivparty.lua` as main script.
- [x] **Event Registration:** Replace Windower load events with Ashita's structure.
    - *Code:* `ashita.events.register('load', 'xivparty_load', function() ... end)`
- [x] **Print Test:** Added success message using `chat` module on load event.

### Test Criteria
- Run `/addon load xivparty` in the game chat.
- Success: "XivParty Loaded" appears in the chat log.
- Success: `/addon unload xivparty` works without crashing.

---

## Milestone 2: The "Windower Shim" (Data Layer)
**Goal:** Create an adapter layer so existing logic can access game data without rewriting every function call.

### Tasks
- [x] **Create Shim File:** Created `adapter.lua`.
- [x] **Map Party Data:** Implemented `windower.ffxi.get_party()` using `AshitaCore:GetMemoryManager():GetParty()`.
- [x] **Map Player Data:** Implemented `windower.ffxi.get_player()` using `GetPlayerEntity()` and `GetMemoryManager():GetPlayer()`.
- [x] **Map Commands:** Implemented `windower.send_command()` -> `AshitaCore:GetChatManager():QueueCommand()`.
- [x] **Additional Mappings:** Also implemented:
    - `windower.ffxi.get_info()` - zone and logged_in status
    - `windower.ffxi.get_mob_by_target()` - target/subtarget info
    - `windower.add_to_chat()` - chat logging
    - `windower.addon_path` - addon directory path
    - `windower.file_exists()` - file existence check
- [x] **Verify Indices:** Ashita uses 0-17 indices (0-5 per party), matching Windower's expected structure.

### Test Criteria
- Run `/xp test` to verify adapter functions.
- Run `/xp party` to see party member names and HP values.
- Run `/xp player` to see current player data.

---

## Milestone 3: UI Engine Swap (Rendering)
**Goal:** Replace Windower Primitives (`windower.prim`) with Ashita v4's Sprite/Font system.

### Tasks
- [x] **Analyze Assets:** Identify where `uiElement.lua` and `uiImage.lua` create primitives.
- [x] **Implementation:** Replace `windower.prim.create` with Ashita primitives via `images.lua` / `texts.lua` shims.
- [x] **The Render Loop:** Implement the `d3d_present` event.
    - *Critical Difference:* Windower primitives persist. Ashita sprites often need to be drawn explicitly every frame inside the render loop.
- [x] **Positioning:** Use existing layout math with `windower.get_windower_settings()` and autoscale when `scale=0`; clamp out-of-bounds and save.
- [x] **Debug Commands:** `/xp testui` renders a test texture at (100,100); `/xp hideui` toggles visibility; `/xp testshim` logs adapter status.

### Test Criteria
- Hardcode a single image (e.g., the Job Icon or a background bar) to appear at 100, 100.
- Success: The image appears on screen and persists. *(Met via `/xp testui`; present hook keeps debug image visible.)*

---

## Milestone 4: Event & Packet Wiring
**Goal:** Enable real-time updates for HP, MP, TP, and Buffs.

### Tasks
- [x] **Packet Listener:** Switched to `ashita.events.register('packet_in', ...)`.
- [ ] **Packet Parsing:** Verify if `struct.unpack` syntax needs adjustment for Ashita's struct library; currently using manual string parsing for buff packet.
- [x] **Zone Changes:** Hooked 0x0B/0x0A to hide/reset UI during zoning.
- [ ] **Party Updates (0xDD):** Parse job/HP/MP/TP and update players.
- [ ] **Char Updates (0xDF):** Parse job/HP/MP/TP and update players.
- [ ] **Buff Tracking:** 0x076 party buff packet wired; main-player buffs still pending resource lookup.
- [ ] **KNOWN GAP:** Self stats via party data are still zero; need to switch to direct memory reads (Ashita player/party structs) to populate HP/MP/TP/HPP/MPP for p0 (reference tparty / Ashita.h).

### Test Criteria
- Have a party member take damage or gain a buff.
- Success: The internal state (print to console) updates immediately.
- Success: The UI (if Milestone 3 is done) updates the bar/icon.

---

## Milestone 5: Input & Configuration
**Goal:** Enable user interaction (mouse targeting) and persistent settings.

### Tasks
- [ ] **Settings Library:** Replace Windower's config lib with Ashita's `require('settings')`.
- [ ] **Load/Save:** Ensure `settings.load()` reads the existing JSON/Lua config format correctly.
- [ ] **Mouse Handling:** Register the `mouse` event to detect clicks on the party bars.
    - *Code:* `ashita.events.register('mouse', 'mouse_cb', function(e) ...)`
- [ ] **Hit Testing:** Ensure mouse coordinates match the UI element coordinates (Ashita scaling vs Windower scaling).

### Test Criteria
- Click on a party member's bar.
- Success: The game targets that party member.
- Change a setting (e.g., range) and reload.
- Success: The setting persists.
