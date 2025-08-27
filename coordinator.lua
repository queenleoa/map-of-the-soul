-- coordinator.lua
-- Thin coordinator: registers artwork agents and caches the evolving map.
-- Exposes state to HyperBEAM via ~patch@1.0 for fast frontend reads.

local json = require('json')

CoordinatorState = CoordinatorState or {
  artworkAgents   = {},   -- pid => artworkId (who registered)
  relationshipMap = {},   -- srcPid => { dstPid => edge }
  lastMapUpdate   = os.time(),
  totalAgents     = 0
}

-- Build + publish a compact snapshot for the frontend cache
local function patchState()
  local snapshot = {
    nodes       = {},
    edges       = {},
    lastUpdate  = CoordinatorState.lastMapUpdate,
    totalAgents = CoordinatorState.totalAgents
  }

  for pid, _ in pairs(CoordinatorState.artworkAgents) do
    snapshot.nodes[#snapshot.nodes + 1] = { id = pid, type = "artwork" }
  end

  for src, rels in pairs(CoordinatorState.relationshipMap) do
    for dst, edge in pairs(rels) do
      snapshot.edges[#snapshot.edges + 1] = {
        source = src,
        target = dst,
        type   = edge.type,         -- duplicate | cousin | influence | mood-sibling | related
        weight = edge.weight or 0,  -- 0..1
        scores = edge.scores or {}, -- { semantic=.., style=.., emotion=.. }
        simham = edge.simham or nil
      }
    end
  end

  Send({ device = 'patch@1.0', cache = { map = snapshot } })
end

local function upsertEdge(src, dst, edge)
  CoordinatorState.relationshipMap[src] = CoordinatorState.relationshipMap[src] or {}
  CoordinatorState.relationshipMap[src][dst] = edge
end

-- Register an artwork agent (called by the agent itself)
Handlers.add('Register-Agent', { Action = 'Register-Agent' }, function (msg)
  local tags = msg.Tags or {}
  local artworkId = tags.ArtworkId or msg.ArtworkId or msg.Data
  local agentPID  = msg.From

  if artworkId and agentPID then
    if not CoordinatorState.artworkAgents[agentPID] then
      CoordinatorState.totalAgents = CoordinatorState.totalAgents + 1
    end
    CoordinatorState.artworkAgents[agentPID] = artworkId
    CoordinatorState.lastMapUpdate = os.time()
    patchState()
    msg.reply({ Action = 'Registered', Data = 'ok' })
  else
    msg.reply({ Action = 'Error', Data = 'Missing ArtworkId' })
  end
end)

-- Store/merge a relationship edge announced by an agent
Handlers.add('Relationship-Update', { Action = 'Relationship-Update' }, function (msg)
  local tags = msg.Tags or {}
  local src  = msg.From
  local dst  = tags.Peer
  if not dst then return end

  local edge = {
    type   = tags.Type or 'related',
    weight = tonumber(tags.Weight or '0') or 0,
    simham = tonumber(tags.SimHam or '0') or 0,
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

-- Return the current map snapshot (also available via /cache/map)
Handlers.add('Get-Map', { Action = 'Get-Map' }, function (msg)
  local snapshot = {
    nodes       = {},
    edges       = {},
    lastUpdate  = CoordinatorState.lastMapUpdate,
    totalAgents = CoordinatorState.totalAgents
  }

  for pid, _ in pairs(CoordinatorState.artworkAgents) do
    snapshot.nodes[#snapshot.nodes + 1] = { id = pid, type = 'artwork' }
  end

  for src, rels in pairs(CoordinatorState.relationshipMap) do
    for dst, edge in pairs(rels) do
      snapshot.edges[#snapshot.edges + 1] =
        { source = src, target = dst, type = edge.type, weight = edge.weight, scores = edge.scores, simham = edge.simham }
    end
  end

  msg.reply({ Action = 'Map', Data = json.encode(snapshot) })
end)

-- Debug helper: dump raw state
Handlers.add('DumpState', { Action = 'DumpState' }, function (msg)
  local info = {
    totalAgents = CoordinatorState.totalAgents,
    nodes       = CoordinatorState.artworkAgents,
    edges       = CoordinatorState.relationshipMap,
    lastUpdate  = CoordinatorState.lastMapUpdate
  }
  msg.reply({ Action = 'State', Data = json.encode(info) })
end)

-- Patch on boot so FE can read immediately
if not __BootPatched then
  __BootPatched = true
  patchState()
end
