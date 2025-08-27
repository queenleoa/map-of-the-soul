-- art_agent.lua
-- Per-artwork agent. Owns all compute & peer comms. Coordinator only gets map updates.

local json = require('json')

-- Filled at runtime via Action=Config from your console/script
COORDINATOR_PID = COORDINATOR_PID or nil
DISCOVERY_PID   = DISCOVERY_PID or nil
LLM_WORKER_PID  = LLM_WORKER_PID or nil

-- Local thresholds (tune later)
DUP_HAMMING = 3            -- SimHash (32-bit) Hamming <= 3 => near-dup
T_DUP = 0.95               -- LLM gate for duplicates (semantic & style high)
T_COUSIN = 0.85
T_INFL  = 0.70

Artwork = Artwork or {
  id = nil,
  text = nil,
  canonical = nil,  -- FNV1a-32 string hash of canonical text
  simhash = nil,    -- 32-bit int
  prefix  = nil,    -- top N bits as hex string prefix
  peers = {},       -- known peer PIDs
  edges = {}        -- peerPID -> edge {type, weight, scores, simham}
}

-- ====== Utility: canonicalize, FNV1a32, SimHash32, Hamming ======
local bit = bit32

local function canonicalize(s)
  s = s or ''
  s = s:gsub("\r", "\n"):gsub("\t", " ")
  s = s:lower():gsub("[^%w%s]", " ")
  s = s:gsub("%s+", " ")
  s = s:match("^%s*(.-)%s*$") or s
  return s
end

local function fnv1a32(s)
  local hash = 2166136261
  for i = 1, #s do
    hash = bit.bxor(hash, s:byte(i))
    hash = (hash * 16777619) % 2^32
  end
  return hash
end

local function shingles(words, k)
  local out = {}
  for i=1, (#words - k + 1) do
    local g = table.concat(words, ' ', i, i+k-1)
    table.insert(out, g)
  end
  if #out == 0 and #words > 0 then out = { table.concat(words, ' ') } end
  return out
end

local function split_words(s)
  local words = {}
  for w in s:gmatch('%S+') do table.insert(words, w) end
  return words
end

local function simhash32_from_text(s)
  local words = split_words(s)
  local grams = shingles(words, 3)
  local v = {}
  for i=0,31 do v[i]=0 end
  for _, g in ipairs(grams) do
    local h = fnv1a32(g)
    for i=0,31 do
      local bit_i = bit.band(bit.rshift(h, i), 1)
      if bit_i == 1 then v[i] = v[i] + 1 else v[i] = v[i] - 1 end
    end
  end
  local h = 0
  for i=0,31 do
    if v[i] >= 0 then h = bit.bor(h, bit.lshift(1, i)) end
  end
  return h
end

local function hamming32(a,b)
  local x = bit.bxor(a,b)
  local c = 0
  for _=0,31 do
    if bit.band(x,1)==1 then c=c+1 end
    x = bit.rshift(x,1)
  end
  return c
end

local function prefix_hex(simhash, bits)
  bits = bits or 12
  local mask = bit.lshift(1, bits) - 1
  local p = bit.band(simhash, mask)
  return string.format('%03x', p)  -- 12 bits => 3 hex chars
end

-- ====== Core actions ======
local function announce_and_discover()
  if not DISCOVERY_PID then return end
  ao.send({ Target = DISCOVERY_PID, Action = 'RegisterPrefix', Prefix = Artwork.prefix })
  ao.send({ Target = DISCOVERY_PID, Action = 'QueryPrefix',  Prefix = Artwork.prefix })
end

local function edge_type_from(scores, simham)
  local s = scores.semantic or 0
  local st= scores.style or 0
  local e = scores.emotion or 0
  local avg = (s + st + e) / 3
  if simham and simham <= DUP_HAMMING and s > 0.9 and st > 0.9 then
    return 'duplicate', math.max(s, st)
  elseif s >= T_COUSIN and st >= T_INFL then
    return 'cousin', avg
  elseif st >= T_INFL then
    return 'influence', st
  elseif e >= T_INFL then
    return 'mood-sibling', e
  else
    return 'related', avg
  end
end

local function send_relationship_update(peerPID, scores, simham)
  local etype, weight = edge_type_from(scores, simham)
  Artwork.edges[peerPID] = { type = etype, weight = weight, scores = scores, simham = simham }
  if COORDINATOR_PID then
    ao.send({ Target = COORDINATOR_PID, Action = 'Relationship-Update', Peer = peerPID, Type = etype, Weight = tostring(weight), SimHam = tostring(simham or 0), Data = json.encode(scores) })
  end
  -- Wake peer so it can mirror
  ao.send({ Target = peerPID, Action = 'Relation-Notify', From = ao.id, Type = etype, Weight = tostring(weight), SimHam = tostring(simham or 0), Data = json.encode(scores) })
end

-- ====== Handlers ======
Handlers.add('Config', { Action = 'Config' }, function(msg)
  if msg.Tags.Coordinator then COORDINATOR_PID = msg.Tags.Coordinator end
  if msg.Tags.Discovery  then DISCOVERY_PID   = msg.Tags.Discovery  end
  if msg.Tags.LLMWorker  then LLM_WORKER_PID  = msg.Tags.LLMWorker  end
  msg.reply({ Action = 'OK' })
end)

Handlers.add('InitArtwork', { Action = 'InitArtwork' }, function(msg)
  local body = msg.Data or ''
  Artwork.text = body
  Artwork.id = Artwork.id or (msg.Tags.ArtworkId or tostring(os.time()))
  local canon = canonicalize(body)
  Artwork.canonical = fnv1a32(canon)
  Artwork.simhash = simhash32_from_text(canon)
  Artwork.prefix  = prefix_hex(Artwork.simhash, 12)
  -- Register with coordinator
  if COORDINATOR_PID then
    ao.send({ Target = COORDINATOR_PID, Action = 'Register-Agent', ArtworkId = Artwork.id })
  end
  -- Announce + discover peers
  announce_and_discover()
  msg.reply({ Action = 'Initialized', Data = json.encode({ prefix = Artwork.prefix, simhash = Artwork.simhash, canonical = Artwork.canonical }) })
end)

Handlers.add('QueryResult', { Action = 'QueryResult' }, function(msg)
  local ok, obj = pcall(json.decode, msg.Data or '{}')
  if not ok or not obj.peers then return end
  for _, pid in ipairs(obj.peers) do
    if not Artwork.peers[pid] then
      Artwork.peers[pid] = true
      -- Say hello with hashes so peer can compare
      ao.send({ Target = pid, Action = 'Hello', Canonical = tostring(Artwork.canonical), SimHash = tostring(Artwork.simhash), Prefix = Artwork.prefix, ArtworkId = Artwork.id })
    end
  end
end)

Handlers.add('Hello', { Action = 'Hello' }, function(msg)
  -- Respond with our info + our text excerpt so peer can score locally
  local payload = { text = Artwork.text }
  ao.send({ Target = msg.From, Action = 'Hello-Reply', Canonical = tostring(Artwork.canonical), SimHash = tostring(Artwork.simhash), Prefix = Artwork.prefix, ArtworkId = Artwork.id, Data = json.encode(payload) })
  -- Also evaluate the incoming peer
  local their_canon = tonumber(msg.Tags.Canonical or msg.Canonical or '0')
  local their_hash  = tonumber(msg.Tags.SimHash or msg.SimHash or '0')
  local their_payload = {}
  pcall(function() their_payload = json.decode(msg.Data or '{}') end)
  local their_text = their_payload.text or ''
  local simham = hamming32(Artwork.simhash, their_hash)
  if their_canon == Artwork.canonical then
    send_relationship_update(msg.From, { semantic = 1, style = 1, emotion = 1 }, 0)
    return
  end
  if simham <= DUP_HAMMING then
    send_relationship_update(msg.From, { semantic = 0.98, style = 0.96, emotion = 0.9 }, simham)
    return
  end
  -- Otherwise, ask the LLM worker for tri-head scores using both texts
  if LLM_WORKER_PID and #their_text > 0 then
    ao.send({ Target = LLM_WORKER_PID, Action = 'ScorePair', Data = json.encode({ src = ao.id, dst = msg.From, textA = Artwork.text, textB = their_text }) })
  end
end)

Handlers.add('Hello-Reply', { Action = 'Hello-Reply' }, function(msg)
  local their_canon = tonumber(msg.Tags.Canonical or msg.Canonical or '0')
  local their_hash  = tonumber(msg.Tags.SimHash or msg.SimHash or '0')
  local their_payload = {}
  pcall(function() their_payload = json.decode(msg.Data or '{}') end)
  local their_text = their_payload.text or ''
  local simham = hamming32(Artwork.simhash, their_hash)
  if their_canon == Artwork.canonical then
    send_relationship_update(msg.From, { semantic = 1, style = 1, emotion = 1 }, 0)
    return
  end
  if simham <= DUP_HAMMING then
    send_relationship_update(msg.From, { semantic = 0.98, style = 0.96, emotion = 0.9 }, simham)
    return
  end
  if LLM_WORKER_PID and #their_text > 0 then
    ao.send({ Target = LLM_WORKER_PID, Action = 'ScorePair', Data = json.encode({ src = ao.id, dst = msg.From, textA = Artwork.text, textB = their_text }) })
  end
end)

Handlers.add('Score-Result', { Action = 'Score-Result' }, function(msg)
  local ok, obj = pcall(json.decode, msg.Data or '{}')
  if not ok or not obj.scores or not obj.dst then return end
  local peer = obj.dst
  -- Without peer text, this is a half-estimate; still good for demo. (Day 3: exchange snippets for higher fidelity.)
  send_relationship_update(peer, obj.scores, Artwork.simhash and 999 or nil)
end)

Handlers.add('Relation-Notify', { Action = 'Relation-Notify' }, function(msg)
  local ok, scores = pcall(json.decode, msg.Data or '{}')
  local simham = tonumber(msg.Tags.SimHam or '0')
  Artwork.edges[msg.From] = { type = msg.Tags.Type or 'related', weight = tonumber(msg.Tags.Weight or '0'), scores = ok and scores or {}, simham = simham }
end)