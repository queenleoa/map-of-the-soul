-- coordinator_agent.lua
local json = require("json")
local ArweaveStorage = require("utils.arweave_storage")

-- Coordinator state
Coordinator = Coordinator or {}
Coordinator.agents = {}  -- All registered agents
Coordinator.relationships = {}  -- All relationships
Coordinator.map_scholar = {}  -- Scholar map data
Coordinator.map_mystic = {}  -- Mystic map data (for future)
Coordinator.stats = {
    total_agents = 0,
    total_relationships = 0,
    duplicates_found = 0,
    versions_found = 0,
    siblings_found = 0,
    cousins_found = 0,
    distant_cousins_found = 0
}

-- Register new agent
function Coordinator.registerAgent(agent_data)
    local agent_id = agent_data.agent_id
    
    -- Check for duplicate
    for id, agent in pairs(Coordinator.agents) do
        if agent.text_hash == agent_data.text_hash then
            Coordinator.stats.duplicates_found = Coordinator.stats.duplicates_found + 1
            return {
                status = "duplicate",
                original_agent = id
            }
        end
    end
    
    -- Store agent
    Coordinator.agents[agent_id] = {
        id = agent_id,
        text_hash = agent_data.text_hash,
        fingerprint = agent_data.fingerprint,
        analysis = agent_data.analysis,
        metrics = agent_data.metrics,
        registered_at = os.time(),
        relationships = {}
    }
    
    Coordinator.stats.total_agents = Coordinator.stats.total_agents + 1
    
    -- Update map
    Coordinator.updateMap("scholar", agent_id)
    
    return {
        status = "registered",
        agent_id = agent_id
    }
end

-- Get random agents for discovery
function Coordinator.getRandomAgents(requester_id, count)
    count = count or 10
    local available_agents = {}
    
    -- Collect all agents except requester
    for id, agent in pairs(Coordinator.agents) do
        if id ~= requester_id then
            table.insert(available_agents, agent)
        end
    end
    
    -- Shuffle and select
    local selected = {}
    local indices = {}
    
    for i = 1, #available_agents do
        indices[i] = i
    end
    
    -- Fisher-Yates shuffle
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    
    -- Select up to count agents
    for i = 1, math.min(count, #available_agents) do
        table.insert(selected, available_agents[indices[i]])
    end
    
    return selected
end

-- Register relationship
function Coordinator.registerRelationship(rel_data)
    local key = rel_data.agent1 .. "-" .. rel_data.agent2
    
    -- Avoid duplicates
    if Coordinator.relationships[key] then
        return {status = "already_exists"}
    end
    
    -- Store relationship
    Coordinator.relationships[key] = {
        agent1 = rel_data.agent1,
        agent2 = rel_data.agent2,
        type = rel_data.type,
        score = rel_data.score,
        justification = rel_data.justification,
        created_at = os.time()
    }
    
    -- Update agent records
    if Coordinator.agents[rel_data.agent1] then
        table.insert(Coordinator.agents[rel_data.agent1].relationships, {
            peer_id = rel_data.agent2,
            type = rel_data.type,
            score = rel_data.score
        })
    end
    
    if Coordinator.agents[rel_data.agent2] then
        table.insert(Coordinator.agents[rel_data.agent2].relationships, {
            peer_id = rel_data.agent1,
            type = rel_data.type,
            score = rel_data.score
        })
    end
    
    -- Update stats
    Coordinator.stats.total_relationships = Coordinator.stats.total_relationships + 1
    local stat_key = rel_data.type .. "s_found"
    Coordinator.stats[stat_key] = (Coordinator.stats[stat_key] or 0) + 1
    
    -- Update map
    Coordinator.updateMap("scholar", rel_data.agent1)
    Coordinator.updateMap("scholar", rel_data.agent2)
    
    return {status = "registered"}
end

-- Update map data
function Coordinator.updateMap(map_type, agent_id)
    local map = map_type == "scholar" and Coordinator.map_scholar or Coordinator.map_mystic
    local agent = Coordinator.agents[agent_id]
    
    if not agent then return end
    
    -- Calculate position based on relationships and themes
    local x, y = Coordinator.calculatePosition(agent, map_type)
    
    map[agent_id] = {
        id = agent_id,
        x = x,
        y = y,
        themes = agent.metrics.themes,
        form = agent.metrics.form,
        connections = agent.relationships
    }
    
    -- Periodically store map snapshot to Arweave
    if Coordinator.stats.total_agents % 10 == 0 then
        ArweaveStorage.storeMapSnapshot(map_type, {
            agents = map,
            stats = Coordinator.stats,
            agent_count = Coordinator.stats.total_agents
        })
    end
end

-- Calculate position for agent on map
function Coordinator.calculatePosition(agent, map_type)
    -- Simple force-directed positioning
    -- In production, use more sophisticated layout algorithms
    
    local x = math.random() * 1000
    local y = math.random() * 1000
    
    -- Adjust based on relationships
    for _, rel in ipairs(agent.relationships or {}) do
        local peer = Coordinator.agents[rel.peer_id]
        if peer and Coordinator.map_scholar[rel.peer_id] then
            local peer_pos = Coordinator.map_scholar[rel.peer_id]
            
            -- Closer relationships = closer positions
            local distance = 100
            if rel.type == "sibling" then
                distance = 50
            elseif rel.type == "cousin" then
                distance = 75
            elseif rel.type == "distant_cousin" then
                distance = 100
            end
            
            -- Move towards peer
            x = peer_pos.x + (math.random() - 0.5) * distance
            y = peer_pos.y + (math.random() - 0.5) * distance
        end
    end
    
    return x, y
end

-- Get map data for UI
function Coordinator.getMapData(map_type)
    local map = map_type == "scholar" and Coordinator.map_scholar or Coordinator.map_mystic
    
    -- Format for UI consumption
    local nodes = {}
    local edges = {}
    
    for agent_id, data in pairs(map) do
        table.insert(nodes, {
            id = agent_id,
            x = data.x,
            y = data.y,
            label = table.concat(data.themes or {}, ", "),
            form = data.form
        })
        
        for _, rel in ipairs(data.connections or {}) do
            table.insert(edges, {
                source = agent_id,
                target = rel.peer_id,
                type = rel.type,
                weight = rel.score
            })
        end
    end
    
    return {
        nodes = nodes,
        edges = edges,
        stats = Coordinator.stats
    }
end

-- Handler: Register agent
Handlers.add(
    "Register-Agent",
    Handlers.utils.hasMatchingTag("Action", "Register-Agent"),
    function(msg)
        local agent_data = json.decode(msg.Data)
        local result = Coordinator.registerAgent(agent_data)
        
        Send({
            Target = msg.From,
            Action = "Registration-Result",
            Data = json.encode(result)
        })
        
        print("Agent registered: " .. agent_data.agent_id)
    end
)

-- Handler: Get random agents
Handlers.add(
    "Get-Random-Agents",
    Handlers.utils.hasMatchingTag("Action", "Get-Random-Agents"),
    function(msg)
        local request = json.decode(msg.Data)
        local agents = Coordinator.getRandomAgents(request.requester, request.count)
        
        Send({
            Target = msg.From,
            Action = "Initial-Agents",
            Data = json.encode(agents)
        })
    end
)

-- Handler: Register relationship
Handlers.add(
    "Register-Relationship",
    Handlers.utils.hasMatchingTag("Action", "Register-Relationship"),
    function(msg)
        local rel_data = json.decode(msg.Data)
        rel_data.agent1 = msg.From  -- Ensure it's from the claiming agent
        
        local result = Coordinator.registerRelationship(rel_data)
        
        Send({
            Target = msg.From,
            Action = "Relationship-Registered",
            Data = json.encode(result)
        })
    end
)

-- Handler: Get specific agent info
Handlers.add(
    "Get-Agent-Info",
    Handlers.utils.hasMatchingTag("Action", "Get-Agent-Info"),
    function(msg)
        local request = json.decode(msg.Data)
        local agent_info = {}
        
        for _, agent_id in ipairs(request.agent_ids) do
            if Coordinator.agents[agent_id] then
                table.insert(agent_info, Coordinator.agents[agent_id])
            end
        end
        
        Send({
            Target = msg.From,
            Action = "Agent-Info",
            Data = json.encode(agent_info)
        })
    end
)

-- Handler: Discovery complete notification
Handlers.add(
    "Discovery-Complete",
    Handlers.utils.hasMatchingTag("Action", "Discovery-Complete"),
    function(msg)
        local data = json.decode(msg.Data)
        print("Agent " .. data.agent_id .. " completed discovery")
        print("Found " .. data.summary.total_relationships .. " relationships")
        
        -- Store final state to Arweave
        ArweaveStorage.storeAnalysis(data.agent_id, {
            discovery_complete = true,
            summary = data.summary,
            relationships = data.relationships
        })
    end
)

-- Handler: Get map data for UI
Handlers.add(
    "Get-Map",
    Handlers.utils.hasMatchingTag("Action", "Get-Map"),
    function(msg)
        local map_type = msg.Tags["Map-Type"] or "scholar"
        local map_data = Coordinator.getMapData(map_type)
        
        Send({
            Target = msg.From,
            Action = "Map-Data",
            Data = json.encode(map_data)
        })
    end
)

-- Handler: Get coordinator status
Handlers.add(
    "Get-Status",
    Handlers.utils.hasMatchingTag("Action", "Get-Status"),
    function(msg)
        Send({
            Target = msg.From,
            Action = "Coordinator-Status",
            Data = json.encode({
                stats = Coordinator.stats,
                agent_count = Coordinator.stats.total_agents,
                relationship_count = Coordinator.stats.total_relationships,
                map_sizes = {
                    scholar = #Coordinator.map_scholar,
                    mystic = #Coordinator.map_mystic
                }
            })
        })
    end
)

print("Coordinator initialized and ready")
print("Process ID: " .. ao.id)

return Coordinator