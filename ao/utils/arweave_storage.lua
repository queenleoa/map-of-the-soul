-- arweave_storage.lua
local json = require("json")
local ArweaveStorage = {}

-- Store art agent analysis on Arweave
function ArweaveStorage.storeAnalysis(agent_id, analysis_data)
    -- Since we're calling llm_apus when out of credits,
    -- we store essential data only to minimize storage costs
    local storage_data = {
        agent_id = agent_id,
        timestamp = os.time(),
        fingerprint = analysis_data.fingerprint,
        metrics = analysis_data.metrics,
        hidden_insight = analysis_data.analysis.hidden_insight
    }
    
    Send({
        Target = ao.id,
        Action = "Store-To-Arweave",
        Data = json.encode(storage_data),
        ["Agent-ID"] = agent_id,
        ["Content-Type"] = "application/json",
        ["Data-Type"] = "art-analysis"
    })
    
    return ao.id .. "-" .. os.time()
end

-- Store relationship discovery
function ArweaveStorage.storeRelationship(rel_data)
    -- Compact storage for relationships
    Send({
        Target = ao.id,
        Action = "Store-Relationship",
        Data = json.encode({
            a1 = rel_data.agent1,
            a2 = rel_data.agent2,
            t = rel_data.type,
            s = rel_data.score,
            j = string.sub(rel_data.justification or "", 1, 200) -- Truncate to save space
        }),
        ["Relationship-Type"] = rel_data.type,
        ["Score"] = tostring(rel_data.score)
    })
end

-- Batch store multiple relationships (more efficient)
function ArweaveStorage.batchStoreRelationships(relationships)
    if #relationships == 0 then return end
    
    Send({
        Target = ao.id,
        Action = "Batch-Store-Relationships",
        Data = json.encode(relationships),
        ["Count"] = tostring(#relationships),
        ["Timestamp"] = tostring(os.time())
    })
end

-- Query for agent's previous relationships (lightweight)
function ArweaveStorage.queryRelationships(agent_id, limit)
    -- This would typically use GraphQL, but for now we'll
    -- return a request structure that the agent can handle
    return {
        query = "relationships",
        agent_id = agent_id,
        limit = limit or 10
    }
end

-- Store coordinator map snapshot
function ArweaveStorage.storeMapSnapshot(map_type, map_data)
    Send({
        Target = ao.id,
        Action = "Store-Map-Snapshot",
        Data = json.encode(map_data),
        ["Map-Type"] = map_type, -- "scholar" or "mystic"
        ["Timestamp"] = tostring(os.time()),
        ["Agent-Count"] = tostring(map_data.agent_count or 0)
    })
end

return ArweaveStorage