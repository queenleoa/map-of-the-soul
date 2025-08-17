-- Coordinator Agent - Minimal coordination for spawning agents and API queries only
-- Does NOT manage agent-to-agent communication or duplicate detection

json = require("json")

-- Persistent state
AgentRegistry = AgentRegistry or {}
TotalAgents = TotalAgents or 0
CoordinatorId = CoordinatorId or ao.id

-- Coordinator metadata
AgentType = "CoordinatorAgent"
Version = "1.0.0"

-- Agent module configuration (AO module containing Art Agent code)
ART_AGENT_MODULE = ART_AGENT_MODULE or "YOUR_ART_AGENT_MODULE_TX_ID"
SCHEDULER_UNIT = SCHEDULER_UNIT or "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"

-- Spawn new art agent for uploaded artwork
function spawnArtAgent(artworkData)
    local agentTags = {
        { name = "App-Name", value = "ArtworkAgentNetwork" },
        { name = "Agent-Type", value = "ArtAgent" },
        { name = "Artwork-ID", value = artworkData.id },
        { name = "Content-Type", value = artworkData.type },
        { name = "Coordinator", value = CoordinatorId }
    }
    
    -- Spawn new AO process for the art agent
    ao.spawn(ART_AGENT_MODULE, {
        scheduler = SCHEDULER_UNIT,
        tags = agentTags
    })
end

-- Handle artwork upload and agent spawning
Handlers.add(
    "UploadArtwork",
    Handlers.utils.hasMatchingTag("Action", "Upload-Artwork"),
    function(msg)
        local artworkData = json.decode(msg.Data)
        
        -- Generate unique artwork ID
        artworkData.id = generateArtworkId(artworkData)
        artworkData.uploadedAt = os.time()
        artworkData.uploader = msg.From
        
        -- Spawn dedicated art agent
        local agentProcessId = spawnArtAgent(artworkData)
        
        -- Register the new agent
        AgentRegistry[agentProcessId] = {
            processId = agentProcessId,
            artworkId = artworkData.id,
            artworkType = artworkData.type,
            createdAt = os.time(),
            uploader = msg.From,
            status = "initializing"
        }
        
        TotalAgents = TotalAgents + 1
        
        -- Initialize the spawned agent
        ao.send({
            Target = agentProcessId,
            Action = "Initialize-Agent",
            Data = json.encode({
                artworkData = artworkData,
                coordinatorProcess = CoordinatorId
            })
        })
        
        -- Respond to uploader
        ao.send({
            Target = msg.From,
            Action = "Artwork-Uploaded",
            Data = json.encode({
                artworkId = artworkData.id,
                agentProcessId = agentProcessId,
                status = "success"
            })
        })
    end
)

-- Handle agent initialization confirmations
Handlers.add(
    "AgentInitialized",
    Handlers.utils.hasMatchingTag("Action", "Agent-Initialized"),
    function(msg)
        local initData = json.decode(msg.Data)
        
        -- Update agent status
        if AgentRegistry[msg.From] then
            AgentRegistry[msg.From].status = "active"
            AgentRegistry[msg.From].contentHash = initData.contentHash
        end
    end
)

-- API: Get all agents (for marketplace integration)
Handlers.add(
    "GetAgents",
    Handlers.utils.hasMatchingTag("Action", "Get-Agents"),
    function(msg)
        local agentList = {}
        
        for processId, agentInfo in pairs(AgentRegistry) do
            table.insert(agentList, {
                processId = processId,
                artworkId = agentInfo.artworkId,
                artworkType = agentInfo.artworkType,
                status = agentInfo.status,
                createdAt = agentInfo.createdAt
            })
        end
        
        ao.send({
            Target = msg.From,
            Action = "Agents-Response",
            Data = json.encode({
                totalAgents = TotalAgents,
                agents = agentList
            })
        })
    end
)

-- API: Get agent by artwork ID
Handlers.add(
    "GetAgentByArtwork",
    Handlers.utils.hasMatchingTag("Action", "Get-Agent-By-Artwork"),
    function(msg)
        local artworkId = msg.Tags["Artwork-ID"]
        local foundAgent = nil
        
        for processId, agentInfo in pairs(AgentRegistry) do
            if agentInfo.artworkId == artworkId then
                foundAgent = {
                    processId = processId,
                    artworkId = agentInfo.artworkId,
                    artworkType = agentInfo.artworkType,
                    status = agentInfo.status,
                    createdAt = agentInfo.createdAt
                }
                break
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "Agent-Found",
            Data = json.encode(foundAgent)
        })
    end
)

-- Handle duplicate detection reports (passive logging only)
Handlers.add(
    "DuplicateDetected",
    Handlers.utils.hasMatchingTag("Action", "Duplicate-Detected"),
    function(msg)
        local duplicateData = json.decode(msg.Data)
        
        -- Log duplicate detection (coordinator does NOT coordinate this)
        ao.send({
            Target = ao.id,
            Action = "Log-Event",
            Data = json.encode({
                eventType = "duplicate_detected",
                reportingAgent = duplicateData.reportingAgent,
                duplicateAgent = duplicateData.duplicateAgent,
                similarityScore = duplicateData.similarityScore,
                artworkIds = duplicateData.artworkIds,
                timestamp = duplicateData.timestamp
            })
        })
    end
)

-- Agent health monitoring (passive)
Handlers.add(
    "AgentHeartbeat",
    Handlers.utils.hasMatchingTag("Action", "Agent-Heartbeat"),
    function(msg)
        local heartbeatData = json.decode(msg.Data)
        
        if AgentRegistry[msg.From] then
            AgentRegistry[msg.From].lastHeartbeat = os.time()
            AgentRegistry[msg.From].status = "active"
        end
    end
)

-- API: Get network statistics
Handlers.add(
    "GetNetworkStats",
    Handlers.utils.hasMatchingTag("Action", "Get-Network-Stats"),
    function(msg)
        local activeAgents = 0
        local inactiveAgents = 0
        
        for _, agentInfo in pairs(AgentRegistry) do
            if agentInfo.status == "active" then
                activeAgents = activeAgents + 1
            else
                inactiveAgents = inactiveAgents + 1
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "Network-Stats",
            Data = json.encode({
                totalAgents = TotalAgents,
                activeAgents = activeAgents,
                inactiveAgents = inactiveAgents,
                uptime = os.time() - (StartTime or os.time())
            })
        })
    end
)

-- Utility functions
function generateArtworkId(artworkData)
    local content = artworkData.title .. artworkData.content .. os.time()
    return string.format("artwork_%d", simpleHash(content))
end

function simpleHash(str)
    local hash = 0
    for i = 1, #str do
        hash = hash + string.byte(str, i)
        hash = hash % (2^32)
    end
    return hash
end

-- Initialize coordinator
StartTime = os.time()