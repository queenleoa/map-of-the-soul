-- coordinator.lua
local json = require("json")

-- Coordinator state
Coordinator = Coordinator or {}
Coordinator.agents = {}
Coordinator.relationships = {}
Coordinator.map_positions = {}
Coordinator.stats = {
    total_agents = 0,
    total_relationships = 0,
    duplicates = 0,
    versions = 0,
    siblings = 0,
    cousins = 0,
    distant_cousins = 0,
    discoveries_complete = 0
}

-- Calculate position using force-directed layout
function Coordinator.calculatePosition(agent_id)
    -- First agent at center
    if Coordinator.stats.total_agents == 1 then
        Coordinator.map_positions[agent_id] = {x = 50, y = 50}
        return {x = 50, y = 50}
    end
    
    -- Find related agents and calculate position based on relationships
    local x, y = 50, 50
    local has_relationships = false
    
    for key, rel in pairs(Coordinator.relationships) do
        if rel.agent1 == agent_id or rel.agent2 == agent_id then
            has_relationships = true
            local other_id = rel.agent1 == agent_id and rel.agent2 or rel.agent1
            local other_pos = Coordinator.map_positions[other_id]
            
            if other_pos then
                -- Distance based on relationship type
                local distance = 40  -- default
                if rel.type == "duplicate" then
                    distance = 5
                elseif rel.type == "version" then
                    distance = 10
                elseif rel.type == "sibling" then
                    distance = 15
                elseif rel.type == "cousin" then
                    distance = 25
                elseif rel.type == "distant_cousin" then
                    distance = 35
                end
                
                -- Add some randomness for visual distribution
                local angle = math.random() * 2 * math.pi
                x = other_pos.x + distance * math.cos(angle)
                y = other_pos.y + distance * math.sin(angle)
                
                -- Keep within bounds (0-100)
                x = math.max(5, math.min(95, x))
                y = math.max(5, math.min(95, y))
                break
            end
        end
    end
    
    -- If no relationships, place randomly at edge
    if not has_relationships then
        local edge = math.random(4)
        if edge == 1 then -- top
            x = math.random(10, 90)
            y = 10
        elseif edge == 2 then -- right
            x = 90
            y = math.random(10, 90)
        elseif edge == 3 then -- bottom
            x = math.random(10, 90)
            y = 90
        else -- left
            x = 10
            y = math.random(10, 90)
        end
    end
    
    Coordinator.map_positions[agent_id] = {x = x, y = y}
    return {x = x, y = y}
end

-- Recalculate all positions when relationships change
function Coordinator.recalculatePositions()
    -- Group agents by relationship clusters
    local clusters = {}
    local visited = {}
    
    for agent_id, _ in pairs(Coordinator.agents) do
        if not visited[agent_id] then
            local cluster = {}
            Coordinator.findCluster(agent_id, cluster, visited)
            table.insert(clusters, cluster)
        end
    end
    
    -- Position clusters
    local cluster_angle = 0
    local angle_step = (2 * math.pi) / #clusters
    
    for _, cluster in ipairs(clusters) do
        local cluster_x = 50 + 30 * math.cos(cluster_angle)
        local cluster_y = 50 + 30 * math.sin(cluster_angle)
        
        -- Position agents within cluster
        for i, agent_id in ipairs(cluster) do
            local agent_angle = (2 * math.pi * i) / #cluster
            local radius = math.min(15, 5 + #cluster)
            
            Coordinator.map_positions[agent_id] = {
                x = cluster_x + radius * math.cos(agent_angle),
                y = cluster_y + radius * math.sin(agent_angle)
            }
        end
        
        cluster_angle = cluster_angle + angle_step
    end
end

-- Find connected cluster of agents
function Coordinator.findCluster(agent_id, cluster, visited)
    if visited[agent_id] then return end
    
    visited[agent_id] = true
    table.insert(cluster, agent_id)
    
    -- Find all connected agents
    for key, rel in pairs(Coordinator.relationships) do
        if rel.agent1 == agent_id then
            Coordinator.findCluster(rel.agent2, cluster, visited)
        elseif rel.agent2 == agent_id then
            Coordinator.findCluster(rel.agent1, cluster, visited)
        end
    end
end

-- Register new agent
function Coordinator.registerAgent(data)
    local agent_id = data.agent_id
    
    -- Check for duplicate text
    for id, agent in pairs(Coordinator.agents) do
        if agent.text_hash == data.text_hash then
            print("Duplicate text detected for " .. agent_id)
            return {
                status = "duplicate",
                original_agent = id
            }
        end
    end
    
    -- Store agent with full data
    Coordinator.agents[agent_id] = {
        agent_id = agent_id,
        title = data.title,
        icon = data.icon,
        text_hash = data.text_hash,
        analysis = data.analysis,
        metrics = data.metrics,
        fingerprint = data.fingerprint,
        registered_at = os.time()
    }
    
    Coordinator.stats.total_agents = Coordinator.stats.total_agents + 1
    
    -- Calculate initial position
    local position = Coordinator.calculatePosition(agent_id)
    
    print("Agent registered: " .. (data.title or agent_id))
    
    -- Store snapshot periodically
    if Coordinator.stats.total_agents % 10 == 0 then
        Coordinator.storeSnapshot()
    end
    
    return {
        status = "registered",
        agent_id = agent_id,
        position = position
    }
end

-- Get random agents for discovery
function Coordinator.getRandomAgents(requester_id, count)
    count = count or 10
    local available = {}
    
    for id, agent in pairs(Coordinator.agents) do
        if id ~= requester_id then
            -- Include full agent data for comparison
            table.insert(available, {
                agent_id = id,
                title = agent.title,
                icon = agent.icon,
                text_hash = agent.text_hash,
                analysis = agent.analysis,
                metrics = agent.metrics,
                fingerprint = agent.fingerprint
            })
        end
    end
    
    -- Shuffle
    for i = #available, 2, -1 do
        local j = math.random(i)
        available[i], available[j] = available[j], available[i]
    end
    
    -- Return subset
    local selected = {}
    for i = 1, math.min(count, #available) do
        table.insert(selected, available[i])
    end
    
    return selected
end

-- Register relationship
function Coordinator.registerRelationship(data)
    -- Create unique key for relationship
    local key1 = data.agent1 .. "-" .. data.agent2
    local key2 = data.agent2 .. "-" .. data.agent1
    
    -- Check if already exists
    if Coordinator.relationships[key1] or Coordinator.relationships[key2] then
        return {status = "already_exists"}
    end
    
    -- Store relationship (use smaller ID first for consistent key)
    local key = data.agent1 < data.agent2 and key1 or key2
    Coordinator.relationships[key] = {
        agent1 = data.agent1,
        agent2 = data.agent2,
        type = data.type,
        score = data.score,
        justification = data.justification,
        similarity = data.similarity or "",
        contrasts = data.contrasts or "",
        created_at = os.time()
    }
    
    -- Update stats
    Coordinator.stats.total_relationships = Coordinator.stats.total_relationships + 1
    if data.type == "duplicate" then
        Coordinator.stats.duplicates = Coordinator.stats.duplicates + 1
    elseif data.type == "version" then
        Coordinator.stats.versions = Coordinator.stats.versions + 1
    elseif data.type == "sibling" then
        Coordinator.stats.siblings = Coordinator.stats.siblings + 1
    elseif data.type == "cousin" then
        Coordinator.stats.cousins = Coordinator.stats.cousins + 1
    elseif data.type == "distant_cousin" then
        Coordinator.stats.distant_cousins = Coordinator.stats.distant_cousins + 1
    end
    
    -- Recalculate positions for both agents
    Coordinator.calculatePosition(data.agent1)
    Coordinator.calculatePosition(data.agent2)
    
    print("Relationship registered: " .. data.type .. " between " .. data.agent1 .. " and " .. data.agent2)
    
    return {status = "registered"}
end

-- Get specific agent info
function Coordinator.getAgentInfo(agent_ids)
    local info = {}
    for _, id in ipairs(agent_ids) do
        if Coordinator.agents[id] then
            local agent = Coordinator.agents[id]
            table.insert(info, {
                agent_id = id,
                title = agent.title,
                icon = agent.icon,
                text_hash = agent.text_hash,
                analysis = agent.analysis,
                metrics = agent.metrics,
                fingerprint = agent.fingerprint
            })
        end
    end
    return info
end

-- Get map data for UI
function Coordinator.getMapData()
    local nodes = {}
    local edges = {}
    
    -- Prepare nodes
    for agent_id, agent in pairs(Coordinator.agents) do
        local pos = Coordinator.map_positions[agent_id] or {x = 50, y = 50}
        table.insert(nodes, {
            id = agent_id,
            title = agent.title,
            icon = agent.icon,
            x = pos.x,
            y = pos.y,
            analysis = agent.analysis,
            metrics = agent.metrics
        })
    end
    
    -- Prepare edges
    for key, rel in pairs(Coordinator.relationships) do
        table.insert(edges, {
            from = rel.agent1,
            to = rel.agent2,
            type = rel.type,
            score = rel.score,
            justification = rel.justification,
            similarity = rel.similarity,
            contrasts = rel.contrasts
        })
    end
    
    return {
        nodes = nodes,
        edges = edges,
        stats = Coordinator.stats
    }
end

-- Store snapshot to Arweave (direct implementation)
function Coordinator.storeSnapshot()
    local map_data = Coordinator.getMapData()
    
    -- Store directly using Send
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
    
    print("Stored snapshot with " .. Coordinator.stats.total_agents .. " agents and " .. 
          Coordinator.stats.total_relationships .. " relationships")
end

-- Handler: Register agent
Handlers.add(
    "Register-Agent",
    Handlers.utils.hasMatchingTag("Action", "Register-Agent"),
    function(msg)
        local data = json.decode(msg.Data)
        local result = Coordinator.registerAgent(data)
        
        Send({
            Target = msg.From,
            Action = "Registration-Result", 
            Data = json.encode(result)
        })
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
            Action = "Random-Agents",
            Data = json.encode(agents)
        })
    end
)

-- Handler: Register relationship
Handlers.add(
    "Register-Relationship",
    Handlers.utils.hasMatchingTag("Action", "Register-Relationship"),
    function(msg)
        local data = json.decode(msg.Data)
        local result = Coordinator.registerRelationship(data)
        
        Send({
            Target = msg.From,
            Action = "Relationship-Registered",
            Data = json.encode(result)
        })
    end
)

-- Handler: Get agent info
Handlers.add(
    "Get-Agent-Info",
    Handlers.utils.hasMatchingTag("Action", "Get-Agent-Info"),
    function(msg)
        local request = json.decode(msg.Data)
        local info = Coordinator.getAgentInfo(request.agent_ids)
        
        Send({
            Target = msg.From,
            Action = "Agent-Info",
            Data = json.encode(info)
        })
    end
)

-- Handler: Discovery complete
Handlers.add(
    "Discovery-Complete",
    Handlers.utils.hasMatchingTag("Action", "Discovery-Complete"),
    function(msg)
        local data = json.decode(msg.Data)
        Coordinator.stats.discoveries_complete = Coordinator.stats.discoveries_complete + 1
        
        print("Agent " .. data.agent_id .. " completed discovery")
        print("Found " .. data.summary.total_relationships .. " relationships")
        
        -- Store final snapshot when all discoveries complete
        if Coordinator.stats.discoveries_complete % 5 == 0 then
            Coordinator.storeSnapshot()
        end
    end
)

-- Handler: Get map data
Handlers.add(
    "Get-Map",
    Handlers.utils.hasMatchingTag("Action", "Get-Map"),
    function(msg)
        local map_data = Coordinator.getMapData()
        
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
                total_agents = Coordinator.stats.total_agents,
                total_relationships = Coordinator.stats.total_relationships,
                discoveries_complete = Coordinator.stats.discoveries_complete
            })
        })
    end
)

print("Coordinator initialized")
print("Process ID: " .. ao.id)

return Coordinator