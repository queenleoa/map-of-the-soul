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
    distant_cousins = 0
}

-- Calculate position using force-directed layout
function Coordinator.calculatePosition(agent_id)
    local agent = Coordinator.agents[agent_id]
    if not agent then return {x = 50, y = 50} end
    
    -- First agent at center
    if Coordinator.stats.total_agents == 1 then
        return {x = 50, y = 50}
    end
    
    -- Calculate based on relationships
    local x, y = 50, 50
    local has_relationships = false
    
    for _, rel in pairs(Coordinator.relationships) do
        if rel.agent1 == agent_id or rel.agent2 == agent_id then
            has_relationships = true
            local other_id = rel.agent1 == agent_id and rel.agent2 or rel.agent1
            local other_pos = Coordinator.map_positions[other_id]
            
            if other_pos then
                -- Distance based on relationship type
                local distance = 20  -- default
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
    
    -- If no relationships, place at edge
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
    
    return {x = x, y = y}
end

-- Register new agent
function Coordinator.registerAgent(data)
    local agent_id = data.agent_id
    
    -- Check for duplicate text
    for id, agent in pairs(Coordinator.agents) do
        if agent.text_hash == data.text_hash then
            Coordinator.stats.duplicates = Coordinator.stats.duplicates + 1
            return {
                status = "duplicate",
                original_agent = id
            }
        end
    end
    
    -- Store agent
    Coordinator.agents[agent_id] = {
        id = agent_id,
        title = data.title,
        icon = data.icon,
        text_hash = data.text_hash,
        arweave_tx = data.arweave_tx,
        analysis = data.analysis,
        metrics = data.metrics,
        registered_at = os.time()
    }
    
    Coordinator.stats.total_agents = Coordinator.stats.total_agents + 1
    
    -- Calculate position
    Coordinator.map_positions[agent_id] = Coordinator.calculatePosition(agent_id)
    
    -- Store snapshot periodically
    if Coordinator.stats.total_agents % 10 == 0 then
        Coordinator.storeSnapshot()
    end
    
    return {
        status = "registered",
        agent_id = agent_id,
        position = Coordinator.map_positions[agent_id]
    }
end

-- Get random agents for discovery
function Coordinator.getRandomAgents(requester_id, count)
    count = count or 10
    local available = {}
    
    for id, agent in pairs(Coordinator.agents) do
        if id ~= requester_id then
            -- Include full data for comparison
            table.insert(available, {
                agent_id = id,
                title = agent.title,
                icon = agent.icon,
                text_hash = agent.text_hash,
                analysis = agent.analysis,
                metrics = agent.metrics
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
    local key = data.agent1 .. "-" .. data.agent2
    local reverse_key = data.agent2 .. "-" .. data.agent1
    
    -- Check if already exists
    if Coordinator.relationships[key] or Coordinator.relationships[reverse_key] then
        return {status = "already_exists"}
    end
    
    -- Store relationship
    Coordinator.relationships[key] = {
        agent1 = data.agent1,
        agent2 = data.agent2,
        type = data.type,
        score = data.score,
        justification = data.justification,
        arweave_tx = data.arweave_tx,
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
    Coordinator.map_positions[data.agent1] = Coordinator.calculatePosition(data.agent1)
    Coordinator.map_positions[data.agent2] = Coordinator.calculatePosition(data.agent2)
    
    return {status = "registered"}
end

-- Get specific agent info
function Coordinator.getAgentInfo(agent_ids)
    local info = {}
    for _, id in ipairs(agent_ids) do
        if Coordinator.agents[id] then
            table.insert(info, {
                agent_id = id,
                title = Coordinator.agents[id].title,
                icon = Coordinator.agents[id].icon,
                text_hash = Coordinator.agents[id].text_hash,
                analysis = Coordinator.agents[id].analysis,
                metrics = Coordinator.agents[id].metrics
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
            arweave_tx = agent.arweave_tx
        })
    end
    
    -- Prepare edges
    for _, rel in pairs(Coordinator.relationships) do
        table.insert(edges, {
            from = rel.agent1,
            to = rel.agent2,
            type = rel.type,
            score = rel.score,
            justification = rel.justification,
            arweave_tx = rel.arweave_tx
        })
    end
    
    return {
        nodes = nodes,
        edges = edges,
        stats = Coordinator.stats
    }
end

-- Store snapshot to Arweave
function Coordinator.storeSnapshot()
    local snapshot = {
        timestamp = os.time(),
        agents = Coordinator.agents,
        relationships = Coordinator.relationships,
        positions = Coordinator.map_positions,
        stats = Coordinator.stats
    }
    
    Send({
        Target = ao.id,
        Action = "Store-Snapshot",
        Data = json.encode(snapshot)
    })
    
    print("Stored snapshot with " .. Coordinator.stats.total_agents .. " agents")
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
        
        print("Agent registered: " .. data.title)
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
        
        print("Relationship registered: " .. data.type .. " between " .. 
              data.agent1 .. " and " .. data.agent2)
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
                total_relationships = Coordinator.stats.total_relationships
            })
        })
    end
)

print("Coordinator initialized")
print("Process ID: " .. ao.id)

return Coordinator