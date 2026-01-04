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

### 2. Hardcoded server address
**File:** `client.lua:20`
```lua
self.host = "165.227.7.122"
```
No way to configure the server address for local testing or alternative servers.

**Status:** Deferred.

---

### 4. Shared wait counter between phases
**File:** `phase.lua:55`
```lua
self.netplay_wait_frames = 0
```
The counter is shared between delta and state phases. While there's a reset in `netplaySendState`, if phase transitions happen unexpectedly, stale timing data could cause premature timeouts.

**Status:** Deferred.

---

### 5. RNG reseeded on every Game:reset() call
**File:** `game.lua:116`
```lua
self.rng:setSeed(os.time())
```
Every time `Game:reset()` is called (which happens at match start), the RNG is reseeded with `os.time()`. This is separate from the server-provided seed at `game.lua:169` and creates a brief window where the local RNG could be out of sync before the seed override.

**Status:** Ignore.

---

### 6. Charselect uses insecure random seeding
**File:** `charselect.lua:370-372`
```lua
math.randomseed(os.time())
local rand = math.random(#opp_chars)
self.opponent_character = opp_chars[rand]
```
Uses `math.randomseed(os.time())` which resets on every `Charselect:enter()`. While this is only for singleplayer opponent selection, it pollutes the global `math.random` state predictably.

**Status:** Ignore.

---

### 7. Server main loop has no error recovery
**File:** `server/main.lua:538`
```lua
while true do
```
The infinite loop has no try-catch around `socket.select()` or other operations. If a critical error occurs (e.g., socket library failure), the server crashes without cleanup or restart capability.

**Status:** Deferred.

---

### 8. Invalid RNG state could leave game partially modified
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

### 10. Debug prints in production code
**Files:** Throughout codebase
Examples:
- `client.lua:66`: `print("received partial data:" .. partial_data .. ".")`
- `server/main.lua:282-285`: `print(dude1)`, `print(dude1.id)`, etc.

These clutter logs and may leak sensitive information.

**Status:** Deferred.

---

### 11. No reconnection support
If a player disconnects mid-match (network hiccup, game crash), there's no mechanism to rejoin the same match. The match is simply ended.

**Status:** Deferred.

---

### 12. Lobby methods have stub implementations
**File:** `lobby.lua:28-38`
```lua
function Lobby:createCustomGame()
    print("TBD - Create custom game")
end
```
Unimplemented features that could confuse users if exposed in UI.

**Status:** Deferred.

---

### 13. Lobby disconnect timeout may be too long for user experience
**File:** `lobby.lua:21`
```lua
self.DISCONNECT_TIMEOUT = 10
```
The comment says "increased from 3 to 10 seconds for slow/unreliable networks" but 10 seconds of unresponsive UI while disconnecting is poor UX. Users may think the game is frozen.

**Status:** Ignored.

---

### 14. ai_netplay doesn't validate player existence
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

### 15. Sequence numbers could theoretically overflow
**File:** `client.lua:240-241`
```lua
self.our_delta_seq = self.our_delta_seq + 1
self.our_state_seq = self.our_state_seq + 1
```
Sequence numbers increment every turn. While Lua uses 64-bit doubles (safe for ~10^15 values), there's no wraparound handling. Extremely long matches could theoretically have issues.

**Status:** Ignored.

---

### 16. Client ping response creates unnecessary traffic
**File:** `client.lua:185-187`
```lua
function Client:receivePing()
    self:send({type = "ping"})
end
```
The client responds to every server ping with another ping. While the server's `receivePing` doesn't respond back, this is wasteful and could cause issues if packets are duplicated.

**Status:** Ignore

---

### 17. Match pairing order is non-deterministic
**File:** `server/main.lua:659-677`
```lua
local queuers = getQueuers()
while #queuers >= 2 do
    local success = startMatch(queuers[1], queuers[2])
```
`getQueuers()` iterates over `dudes` using `pairs()`, which has no guaranteed order in Lua. If 3+ players queue simultaneously, the pairing is arbitrary and not FIFO (first-in-first-out).

**Status:** Ignored.

---

### 18. Client:update ignores dt parameter
**File:** `game.lua:258` and `client.lua:49`
```lua
-- game.lua:258
self.client:update(dt)

-- client.lua:49
function Client:update()
```
`Game:update(dt)` passes `dt` to `client:update()`, but the client function doesn't accept any parameters. The `dt` is silently ignored. While not currently causing issues, this inconsistency could cause confusion if frame-rate-independent timing is ever needed in the client.

**Status:** Ignored.

---

### 19. Stale dude objects in match queue
**File:** `server/main.lua:659-661`
```lua
local queuers = getQueuers()
while #queuers >= 2 do
    local success = startMatch(queuers[1], queuers[2])
```
`getQueuers()` returns copied dude objects (values from the `dudes` table). If a connection closes between fetching queuers and calling `startMatch`, the code operates on stale data. While `startMatch` validates via `getConnFromID`, there's a brief TOCTOU (time-of-check-time-of-use) gap.

**Status:** Ignored.

---

### 20. No validation in Client:writeDeltaPiece
**File:** `client.lua:376-378`
```lua
function Client:writeDeltaPiece(piece, coords)
    self.our_delta = self.game:serializeDelta(self.our_delta, piece, coords)
end
```
No validation that `piece` or `coords` are valid before passing to `serializeDelta`. A nil piece or coords would cause a crash in `serializeDelta`.

**Status:** Ignored - unreachable through normal code paths.

---

### 21. Server doesn't validate delta/state sequence numbers
**File:** `server/main.lua:344-386`
```lua
local function receiveGameData(data, conn)
    -- ...
    server.send(data, opponent)
```
The server blindly forwards delta/state packets without validating or tracking sequence numbers. The client has sequence validation, but a malicious client could craft packets with arbitrary sequence numbers that bypass client-side duplicate detection.

**Status:** Ignored.

---

### 22. endMatch guard has potential race condition
**File:** `server/main.lua:461-465`
```lua
if ending_match[conn] then
    print("endMatch already in progress for this connection, skipping")
    return
end
ending_match[conn] = true
```
If both players call `endMatch` in the exact same server loop iteration (from the same `socket.select` batch processing multiple ready sockets), there's a brief window where both could pass the guard check before either sets their flag. This could cause duplicate cleanup operations.

**Status:** Ignored.

---

### 23. Inconsistent timer APIs between lobby and client
**File:** `lobby.lua:58,79` vs `client.lua:51,258`
```lua
-- lobby.lua uses love.timer
self.disconnect_start_time = love.timer.getTime()

-- client.lua uses socket.gettime
local current_time = socket.gettime()
```
Mixing `love.timer.getTime()` and `socket.gettime()` for timing operations. While both return seconds with sub-second precision, they may have different reference epochs, making debugging timing issues across the codebase more difficult.

**Status:** Ignored. No functional impact.

---

## Summary Table

| # | Bug | Severity | Status |
|---|-----|----------|--------|
| 1 | Weak RNG seed for matches | Critical | Deferred |
| 2 | Hardcoded server address | Medium | Deferred |
| 4 | Shared wait counter between phases | Medium | Deferred |
| 5 | RNG reseeded on Game:reset() | Medium | Ignore |
| 6 | Charselect insecure random seeding | Medium | Ignore |
| 7 | Server main loop no error recovery | Medium | Deferred |
| 8 | Invalid RNG state partial modification | Medium | Deferred |
| 10 | Debug prints in production | Low | Deferred |
| 11 | No reconnection support | Low | Deferred |
| 12 | Lobby stub implementations | Low | Deferred |
| 13 | Lobby disconnect timeout too long | Low | Ignored |
| 14 | ai_netplay player validation | Low | Deferred |
| 15 | Sequence number overflow | Low | Ignored |
| 16 | Client ping unnecessary traffic | Low | Ignore |
| 17 | Match pairing non-deterministic | Low | Ignored |
| 18 | Client:update ignores dt | Low | Ignored |
| 19 | Stale dude objects in queue | Low | Ignored |
| 20 | writeDeltaPiece no validation | Low | Ignored |
| 21 | Server no sequence validation | Low | Ignored |
| 22 | endMatch race condition | Low | Ignored |
| 23 | Inconsistent timer APIs | Low | Ignored |

### By Severity

| Severity | Count | Action Required |
|----------|-------|-----------------|
| Critical | 1 | 1 deferred |
| Medium | 6 | 4 deferred, 2 ignore |
| Low | 14 | 4 deferred, 10 ignored |

### Action Summary

| Status | Count | Bugs |
|--------|-------|------|
| Deferred | 9 | #1, #2, #4, #7, #8, #10, #11, #12, #14 |
| Ignored | 12 | #5, #6, #13, #15, #16, #17, #18, #19, #20, #21, #22, #23 |
