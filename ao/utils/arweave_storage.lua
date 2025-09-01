-- utils/arweave_storage.lua
local json = require("json")

local ArweaveStorage = {}

-- Store art agent analysis (consistent with scholar_utils parsing)
function ArweaveStorage.storeArtwork(agent_data)
    local storage_data = {
        -- Core identification
        agent_id = agent_data.agent_id,
        title = agent_data.title or "Untitled",
        icon = agent_data.icon or "📝",
        wallet_id = agent_data.wallet_id or ao.id,
        process_id = ao.id,
        
        -- Text data
        text_hash = agent_data.text_hash,
        text_excerpt = string.sub(agent_data.text or "", 1, 500),
        
        -- Analysis (matches scholar_utils.parseAnalysis output)
        analysis = {
            emotional_tone = agent_data.analysis.emotional_tone,
            thematic_elements = agent_data.analysis.thematic_elements,
            stylistic_features = agent_data.analysis.stylistic_features,
            hidden_insight = agent_data.analysis.hidden_insight
        },
        
        -- Metrics (matches scholar_utils.parseMetricsFromResponse output)
        metrics = {
            themes = agent_data.metrics.themes or {},  -- array of theme strings
            emotions = agent_data.metrics.emotions or {},  -- array of emotion strings
            form = agent_data.metrics.form or "unknown",
            register = agent_data.metrics.register or {formality = 0.5, abstractness = 0.5},
            narrative_voice = agent_data.metrics.narrative_voice or "unknown",
            imagery_domains = agent_data.metrics.imagery_domains or {},
            literary_devices = agent_data.metrics.literary_devices or {}
        },
        
        -- Fingerprint (matches scholar_utils.createFingerprint output)
        fingerprint = agent_data.fingerprint,
        
        -- Metadata
        created_at = os.time()
    }
    
    -- AO Send automatically stores on Arweave
    Send({
        Target = ao.id,
        Action = "Artwork-Stored",
        Data = json.encode(storage_data),
        ["Agent-ID"] = agent_data.agent_id,
        ["Title"] = storage_data.title,
        ["Text-Hash"] = agent_data.text_hash
    })
    
    return agent_data.agent_id .. "-" .. os.time()
end

-- Store relationship (consistent with relationship_analyzer output)
function ArweaveStorage.storeRelationship(rel_data)
    local storage_data = {
        -- Agents
        agent1 = rel_data.agent1,
        agent2 = rel_data.agent2,
        
        -- Relationship data (matches relationship_analyzer.parseRelationship output)
        type = rel_data.type,  -- duplicate/version/sibling/cousin/distant_cousin/none
        score = rel_data.score,
        justification = rel_data.justification,
        similarity = rel_data.similarity or "",
        contrasts = rel_data.contrasts or "",
        
        -- Metadata
        discovered_at = os.time()
    }
    
    Send({
        Target = ao.id,
        Action = "Relationship-Stored",
        Data = json.encode(storage_data),
        ["Agent1"] = rel_data.agent1,
        ["Agent2"] = rel_data.agent2,
        ["Type"] = rel_data.type
    })
    
    return "rel-" .. os.time()
end

-- Batch store relationships for efficiency
function ArweaveStorage.batchStoreRelationships(relationships)
    if #relationships == 0 then return nil end
    
    local batch_data = {
        relationships = relationships,
        count = #relationships,
        stored_at = os.time()
    }
    
    Send({
        Target = ao.id,
        Action = "Batch-Relationships-Stored",
        Data = json.encode(batch_data),
        ["Count"] = tostring(#relationships)
    })
    
    return "batch-" .. os.time()
end

-- Store discovery summary
function ArweaveStorage.storeDiscoveryReport(agent_id, summary)
    Send({
        Target = ao.id,
        Action = "Discovery-Complete",
        Data = json.encode({
            agent_id = agent_id,
            summary = summary,
            completed_at = os.time()
        }),
        ["Agent-ID"] = agent_id
    })
    
    return "report-" .. os.time()
end

-- Store coordinator snapshot
function ArweaveStorage.storeMapSnapshot(map_data)
    Send({
        Target = ao.id,
        Action = "Map-Snapshot",
        Data = json.encode({
            nodes = map_data.nodes,
            edges = map_data.edges,
            stats = map_data.stats,
            snapshot_at = os.time()
        }),
        ["Node-Count"] = tostring(#map_data.nodes),
        ["Edge-Count"] = tostring(#map_data.edges)
    })
    
    return "snapshot-" .. os.time()
end

return ArweaveStorage