# Netplay Bugs - Remaining Issues

## NOTE TO CLAUDE
Note that this game uses two randoms: math.random (unreliable random), and the custom self.rng, which is deterministic across platforms.

## CRITICAL

### 1. Weak RNG seed for matches
**File:** `server/main.lua:300`
```lua
local rng_seed = os.time()
```
Using `os.time()` provides only second-level precision. Two matches starting within the same second will have identical RNG seeds, allowing players to potentially predict piece sequences if they know the match start time.

**Status:** Deferred.

---

## MEDIUM

### 6. Hardcoded server address
**File:** `client.lua:20`
```lua
self.host = "165.227.7.122"
```
No way to configure the server address for local testing or alternative servers.

**Status:** Deferred.

---

### 7. State serialization uses underscore delimiter unsafely
**File:** `game.lua:646-654`
```lua
return
    p1char .. "_" .. p2char .. "_" ..
    ...
    p1special .. "_" ..
    p2special .. "_"
```
If any special/character data contains underscores, deserialization at `game.lua:699` will produce incorrect element count, causing state validation failure or data corruption.

**Status:** Deferred.

---

### 8. Shared wait counter between phases
**File:** `phase.lua:55`
```lua
self.netplay_wait_frames = 0
```
The counter is shared between delta and state phases. While there's a reset in `netplaySendState`, if phase transitions happen unexpectedly, stale timing data could cause premature timeouts.

**Status:** Deferred.

---

### 9. RNG reseeded on every Game:reset() call
**File:** `game.lua:116`
```lua
self.rng:setSeed(os.time())
```
Every time `Game:reset()` is called (which happens at match start), the RNG is reseeded with `os.time()`. This is separate from the server-provided seed at `game.lua:169` and creates a brief window where the local RNG could be out of sync before the seed override.

**Status:** Ignore.

---

### 10. Charselect uses insecure random seeding
**File:** `charselect.lua:370-372`
```lua
math.randomseed(os.time())
local rand = math.random(#opp_chars)
self.opponent_character = opp_chars[rand]
```
Uses `math.randomseed(os.time())` which resets on every `Charselect:enter()`. While this is only for singleplayer opponent selection, it pollutes the global `math.random` state predictably.

**Status:** Ignore.

---

### 11. Server main loop has no error recovery
**File:** `server/main.lua:538`
```lua
while true do
```
The infinite loop has no try-catch around `socket.select()` or other operations. If a critical error occurs (e.g., socket library failure), the server crashes without cleanup or restart capability.

**Status:** Deferred.

---

### 12. Invalid RNG state could leave game partially modified
**File:** `game.lua:925`
```lua
self.rng:setState(rng_state)
```
The comment says "Replace RNG state LAST (after all other operations that might fail)" but if the RNG state string is corrupted/invalid, `setState` could fail after all other game state has been modified, leaving an inconsistent state.

**Suggested solutions:**
1. **Pre-validate RNG state:** Before applying any game state changes, validate the RNG state string format. LÖVE's RandomGenerator expects a specific format - check it matches before proceeding.
2. **Wrap in pcall:** Use `pcall(self.rng.setState, self.rng, rng_state)` and if it fails, trigger a desync/disconnect rather than leaving partial state.
3. **Save/restore pattern:** Before deserializing, save the current complete game state. If any step fails (including RNG), restore the saved state and report an error.

**Status:** Deferred (low risk - RNG state corruption is rare and would likely indicate packet tampering).

---

## LOW

### 13. Debug prints in production code
**Files:** Throughout codebase
Examples:
- `client.lua:66`: `print("received partial data:" .. partial_data .. ".")`
- `server/main.lua:282-285`: `print(dude1)`, `print(dude1.id)`, etc.

These clutter logs and may leak sensitive information.

**Status:** Deferred.

---

### 14. No reconnection support
If a player disconnects mid-match (network hiccup, game crash), there's no mechanism to rejoin the same match. The match is simply ended.

**Status:** Deferred.

---

### 15. Lobby methods have stub implementations
**File:** `lobby.lua:28-38`
```lua
function Lobby:createCustomGame()
    print("TBD - Create custom game")
end
```
Unimplemented features that could confuse users if exposed in UI.

**Status:** Deferred.

---

### 16. Lobby disconnect timeout may be too long for user experience
**File:** `lobby.lua:21`
```lua
self.DISCONNECT_TIMEOUT = 10
```
The comment says "increased from 3 to 10 seconds for slow/unreliable networks" but 10 seconds of unresponsive UI while disconnecting is poor UX. Users may think the game is frozen.

**Status:** Ignored.

---

### 17. ai_netplay doesn't validate player existence
**File:** `ai_netplay.lua:11`
```lua
function ai_net:evaluateActions(them_player)
```
The function assumes `them_player` is valid but doesn't verify the player object hasn't been removed from game state during async operations.

**Suggested fix:** Add validation at the start of the function:
```lua
function ai_net:evaluateActions(them_player)
    local game = self.game
    local delta = game.client.their_delta

    -- Validate player exists
    if not them_player then
        print("ai_netplay: them_player is nil")
        return false
    end

    -- Validate player is still in game state
    if them_player ~= game.p1 and them_player ~= game.p2 then
        print("ai_netplay: them_player not found in game state")
        return false
    end
    -- ... rest of function
```

**Status:** Deferred (low risk - player removal during async operations is unlikely in current architecture).

---

### 18. Sequence numbers could theoretically overflow
**File:** `client.lua:240-241`
```lua
self.our_delta_seq = self.our_delta_seq + 1
self.our_state_seq = self.our_state_seq + 1
```
Sequence numbers increment every turn. While Lua uses 64-bit doubles (safe for ~10^15 values), there's no wraparound handling. Extremely long matches could theoretically have issues.

**Status:** Ignored.

---

### 19. Potential infinite loop in queuer matching
**File:** `server/main.lua:632-637`
```lua
while #queuers >= 2 do
    startMatch(queuers[1], queuers[2])
    queuers = getQueuers()
end
```
If `startMatch()` returns `false` (lines 390, 393, 421) without updating the dudes' `queuing` status, the loop will run forever. The dudes remain in the queuers list since their `queuing` flag isn't cleared on failure.

**Status:** Please make it update the queuing status

---

### 20. Server crashes on nil dude access in startMatch debug prints
**File:** `server/main.lua:377-381`
```lua
print(dude1)
print(dude1.id)
print(dude2)
print(dude2.id)
```
These debug prints access `dude.id` before validation. If a race condition causes `dude1` or `dude2` to be nil (disconnect during queue matching), the server crashes.

**Status:** Please check before printing

---

### 21. deserializeState resets me_player/them_player incorrectly
**File:** `game.lua:830`
```lua
self.me_player, self.them_player = self.p1, self.p2
```
This always assigns `me_player = p1`, ignoring the player's actual side. If a player joined as side 2, state comparison would work but any state restoration would break player assignment.

**Status:** Please fix

---

### 22. Client ping response creates unnecessary traffic
**File:** `client.lua:185-187`
```lua
function Client:receivePing()
    self:send({type = "ping"})
end
```
The client responds to every server ping with another ping. While the server's `receivePing` doesn't respond back, this is wasteful and could cause issues if packets are duplicated.

**Status:** Ignore

---

### 23. Assert in sendDeltaConfirmation can crash game
**File:** `client.lua:437-438`
```lua
assert(self.game.current_phase == "NetplayWaitForDelta", ...)
```
Using `assert` crashes the game instead of gracefully handling unexpected phase. One player's game crashes while the opponent continues playing.

**Status:** Hmm. Suggest some ways of fixing this one.

---

### 24. Replay seed is passed as string, not number
**File:** `game.lua:251`
```lua
seed = header[8],
```
The seed is extracted from header as a string but the netplay code at `client.lua:132` validates `type(recv.seed) ~= "number"`. The replay path doesn't convert to number, which could cause inconsistent RNG behavior.

**Status:** Please fix

---

### 25. ending_match guard not cleared on error
**File:** `server/main.lua:445-481`
The `ending_match[conn]` flag is set at line 445 but only cleared at line 481. If an error occurs during cleanup, the flag remains set and blocks future endMatch calls for that connection.

**Status:** Please fix

---

### 26. No content validation for background in queue_details
**File:** `server/main.lua:219-221`
The server validates `background` is a string but not its content. Malicious clients could send strings like `"../../../etc/passwd"` that might cause path traversal issues when used in image lookups on the client side.

**Status:** Please safeguard

---

### 27. handleConnectionTimeout doesn't check client exists
**File:** `phase.lua:188-192`
```lua
client.their_delta = nil
client.their_state = nil
client:endMatch()
```
No check that `client` is valid before accessing properties and calling methods. If the client was already cleared by another code path, this would error.

**Status:** New.

---

### 28. Client:newTurn increments sequence without validating previous turn
**File:** `client.lua:275-278`
```lua
self.our_delta_seq = self.our_delta_seq + 1
self.our_state_seq = self.our_state_seq + 1
```
Sequence numbers increment without verifying the previous turn's delta/state were confirmed. The warnings at lines 259-264 just print without affecting behavior or triggering recovery.

**Status:** New.

---

### 29. pos in deserializeDelta not validated as integer
**File:** `game.lua:462-467`
`pos` is validated to be in range 1-5 but not that it's an integer. A floating point value like `1.5` from a malformed delta could cause unexpected behavior when used as array index.

**Status:** New.

---

### 30. Version check happens after replay parsing
**File:** `game.lua:218-241`
The replay string is parsed into tables before version is checked at line 236. Processing should stop earlier if version won't match, to avoid wasted work and potential issues with malformed data.

**Status:** New.

