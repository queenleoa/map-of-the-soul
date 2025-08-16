-- coordinator.lua
local json = require("json")

-- Agent registry stored in process state
Agents = Agents or {}
ArtworkIndex = ArtworkIndex or {}

-- Handler for registering new artwork
Handlers.add(
    "RegisterArtwork",
    Handlers.utils.hasMatchingTag("Action", "RegisterArtwork"),
    function(msg)
        local artworkId = msg.Tags.ArtworkId
        local contentHash = msg.Tags.ContentHash
        local contentType = msg.Tags.ContentType or "text"
        
        -- Check if artwork already registered
        if Agents[artworkId] then
            ao.send({
                Target = msg.From,
                Action = "RegisterResponse",
                Status = "AlreadyExists",
                AgentId = Agents[artworkId].processId
            })
            return
        end
        
        -- Spawn new art agent process
        local agentProcessId = ao.spawn(
            ao.env.Module.Id,  -- Use same module as coordinator
            {
                ["Process-Type"] = "ArtAgent",
                ["Artwork-Id"] = artworkId,
                ["Content-Hash"] = contentHash,
                ["Content-Type"] = contentType,
                ["Parent-Coordinator"] = ao.id
            }
        )
        
        -- Register agent
        Agents[artworkId] = {
            processId = agentProcessId,
            contentHash = contentHash,
            contentType = contentType,
            registeredAt = msg.Timestamp,
            createdBy = msg.From
        }
        
        -- Add to content hash index for discovery
        if not ArtworkIndex[contentHash] then
            ArtworkIndex[contentHash] = {}
        end
        table.insert(ArtworkIndex[contentHash], agentProcessId)
        
        -- Initialize the new agent
        ao.send({
            Target = agentProcessId,
            Action = "Initialize",
            ArtworkId = artworkId,
            ContentHash = contentHash,
            ContentType = contentType
        })
        
        -- Notify other agents to check for duplicates
        ao.send({
            Target = agentProcessId,
            Action = "DiscoverPeers"
        })
        
        -- Response to caller
        ao.send({
            Target = msg.From,
            Action = "RegisterResponse",
            Status = "Success",
            AgentId = agentProcessId
        })
    end
)

-- API Query: Check if content exists
Handlers.add(
    "QueryContent",
    Handlers.utils.hasMatchingTag("Action", "QueryContent"),
    function(msg)
        local contentHash = msg.Tags.ContentHash
        local results = {}
        
        if ArtworkIndex[contentHash] then
            for _, agentId in ipairs(ArtworkIndex[contentHash]) do
                table.insert(results, agentId)
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "QueryResponse",
            Results = json.encode(results),
            Count = tostring(#results)
        })
    end
)

-- API Query: Get all agents
Handlers.add(
    "ListAgents",
    Handlers.utils.hasMatchingTag("Action", "ListAgents"),
    function(msg)
        local agentList = {}
        for artworkId, agent in pairs(Agents) do
            table.insert(agentList, {
                artworkId = artworkId,
                agentId = agent.processId,
                contentHash = agent.contentHash
            })
        end
        
        ao.send({
            Target = msg.From,
            Action = "ListResponse",
            Agents = json.encode(agentList)
        })
    end
)

-- Publish agent registry to Arweave for discovery
Handlers.add(
    "PublishRegistry",
    Handlers.utils.hasMatchingTag("Action", "PublishRegistry"),
    function(msg)
        -- Store registry on Arweave for agent discovery
        local registry = {
            agents = Agents,
            index = ArtworkIndex,
            timestamp = msg.Timestamp
        }
        
        -- This would create a data item on Arweave
        ao.send({
            Target = ao.id,
            Action = "Data-Write",
            Data = json.encode(registry),
            Tags = {
                ["Content-Type"] = "application/json",
                ["Registry-Type"] = "ArtAgentRegistry",
                ["Coordinator-Id"] = ao.id
            }
        })
    end
)