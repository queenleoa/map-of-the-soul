-- coordinator.lua
-- Thin coordinator: registers artwork agents and caches the evolving map.
-- Exposes state to HyperBEAM via ~patch@1.0 for fast frontend reads.

local json = require('json')

CoordinatorState = CoordinatorState or {
  artworkAgents = {},        -- artworkId => agentPID
  relationshipMap = {},      -- agentPID => { peerPID => edge }
  lastMapUpdate = os.time(),
  totalAgents = 0
}

local function patchState()
  -- Expose a compact snapshot for the frontend.
  local snapshot = {
    nodes = {},
    edges = {},
    lastUpdate = CoordinatorState.lastMapUpdate,
    totalAgents = CoordinatorState.totalAgents
  }
  for pid, _ in pairs(CoordinatorState.artworkAgents) do
    table.insert(snapshot.nodes, { id = pid, type = "artwork" })
  end
  for src, rels in pairs(CoordinatorState.relationshipMap) do
    for dst, edge in pairs(rels) do
      table.insert(snapshot.edges, {
        source = src,
        target = dst,
        type   = edge.type,        -- duplicate | cousin | influence | mood-sibling | related
        weight = edge.weight or 0, -- 0..1
        scores = edge.scores or {},-- { semantic=.., style=.., emotion=.. }
        simham = edge.simham or nil
      })
    end
  end
  Send({ device = 'patch@1.0', cache = { map = snapshot } })
end

local function upsertEdge(src, dst, edge)
  CoordinatorState.relationshipMap[src] = CoordinatorState.relationshipMap[src] or {}
  CoordinatorState.relationshipMap[src][dst] = edge
end

Handlers.add('Register-Agent', { Action = 'Register-Agent' }, function (msg)
  local artworkId = msg.Tags.ArtworkId or msg.ArtworkId or msg.Data
  local agentPID  = msg.From
  if artworkId then
    if not CoordinatorState.artworkAgents[agentPID] then
      CoordinatorState.totalAgents = CoordinatorState.totalAgents + 1
    end
    CoordinatorState.artworkAgents[agentPID] = artworkId
    CoordinatorState.lastMapUpdate = os.time()
    patchState()
    ao.send({ Target = agentPID, Action = 'Registered', Data = 'ok' })
  else
    ao.send({ Target = msg.From, Action = 'Error', Data = 'Missing ArtworkId' })
  end
end)

Handlers.add('Relationship-Update', { Action = 'Relationship-Update' }, function (msg)
  local src = msg.From
  local dst = msg.Tags.Peer
  if not dst then return end
  local edge = {
    type   = msg.Tags.Type or 'related',
    weight = tonumber(msg.Tags.Weight or '0') or 0,
    simham = tonumber(msg.Tags.SimHam or '0') or 0,
    scores = {}
  }
  if msg.Data and #msg.Data > 0 then
    local ok, obj = pcall(json.decode, msg.Data)
    if ok and type(obj) == 'table' then edge.scores = obj end
  end
  upsertEdge(src, dst, edge)
  -- Keep symmetric for display (best-effort)
  upsertEdge(dst, src, edge)
  CoordinatorState.lastMapUpdate = os.time()
  patchState()
end)

Handlers.add('Get-Map', { Action = 'Get-Map' }, function (msg)
  -- Return current patched snapshot (also separately available via /cache/map)
  local snapshot = {
    nodes = {}, edges = {},
    lastUpdate = CoordinatorState.lastMapUpdate,
    totalAgents = CoordinatorState.totalAgents
  }
  for pid, _ in pairs(CoordinatorState.artworkAgents) do
    table.insert(snapshot.nodes, { id = pid, type = 'artwork' })
  end
  for src, rels in pairs(CoordinatorState.relationshipMap) do
    for dst, edge in pairs(rels) do
      table.insert(snapshot.edges, { source=src, target=dst, type=edge.type, weight=edge.weight, scores=edge.scores, simham=edge.simham })
    end
  end
  msg.reply({ Action = 'Map', Data = json.encode(snapshot) })
end)

-- Patch on boot so FE can read immediately
if not __BootPatched then
  __BootPatched = true
  patchState()
end