-- Art Agent Process for individual artwork management
-- This agent is spawned for each piece of artwork and operates autonomously

json = require("json")
crypto = require("crypto")

-- Initialize persistent storage (capitalized variables are auto-persisted in AO)
ArtworkData = ArtworkData or {}
PeerAgents = PeerAgents or {}
ContentHash = ContentHash or nil
SimilarityThreshold = SimilarityThreshold or 10
LastHeartbeat = LastHeartbeat or os.time()
NetworkView = NetworkView or {}
GossipRounds = GossipRounds or 0

-- Agent metadata
AgentId = AgentId or ao.id
Owner = Owner or ao.env.Process.Owner
AgentType = "ArtAgent"
Version = "1.0.0"

-- Initialize agent state
function initializeAgent(artworkData)
    ArtworkData = artworkData
    ContentHash = calculateContentHash(ArtworkData.content)
    
    -- Register with network
    announcePresence()
    
    -- Start gossip protocol
    startGossipProtocol()
    
    -- Begin duplicate detection
    initiateDuplicateSearch()
end

-- Content-based hashing using dHash algorithm (optimized for Lua)
function calculateContentHash(content)
    if ArtworkData.type == "image" then
        return calculateImageHash(content)
    elseif ArtworkData.type == "text" then
        return calculateTextHash(content)
    end
    return calculateGenericHash(content)
end

-- dHash implementation for images
function calculateImageHash(imageData)
    -- Simplified dHash - converts to 9x9 grayscale then calculates gradients
    local pixels = convertToGrayscale(imageData, 9, 9)
    local hash = 0
    
    -- Calculate horizontal gradients
    for y = 1, 9 do
        for x = 1, 8 do
            local offset = (y-1) * 9 + x
            if pixels[offset] < pixels[offset + 1] then
                hash = hash | (1 << ((y-1)*8 + (x-1)))
            end
        end
    end
    
    return tostring(hash)
end

-- SimHash implementation for text content
function calculateTextHash(textContent)
    local features = extractFeatures(textContent)
    local hashBits = {}
    
    -- Initialize hash bits
    for i = 1, 64 do
        hashBits[i] = 0
    end
    
    -- Process each feature
    for _, feature in pairs(features) do
        local featureHash = simpleHash(feature)
        for i = 1, 64 do
            local bit = (featureHash >> (i-1)) & 1
            if bit == 1 then
                hashBits[i] = hashBits[i] + 1
            else
                hashBits[i] = hashBits[i] - 1
            end
        end
    end
    
    -- Convert to final hash
    local finalHash = 0
    for i = 1, 64 do
        if hashBits[i] > 0 then
            finalHash = finalHash | (1 << (i-1))
        end
    end
    
    return tostring(finalHash)
end

function extractFeatures(text)
    -- Extract 3-grams as features
    local features = {}
    local words = splitWords(text)
    
    for i = 1, #words - 2 do
        local trigram = words[i] .. " " .. words[i+1] .. " " .. words[i+2]
        features[trigram] = (features[trigram] or 0) + 1
    end
    
    return features
end

-- Hamming distance calculation for similarity detection
function hammingDistance(hash1, hash2)
    local num1 = tonumber(hash1)
    local num2 = tonumber(hash2)
    local xor = num1 ~ num2  -- XOR operation
    
    -- Count set bits
    local count = 0
    while xor > 0 do
        count = count + (xor & 1)
        xor = xor >> 1
    end
    
    return count
end

-- Check if two content hashes are similar
function areSimilar(hash1, hash2, threshold)
    threshold = threshold or SimilarityThreshold
    return hammingDistance(hash1, hash2) <= threshold
end

-- Announce presence to network using Arweave tags
function announcePresence()
    ao.send({
        Target = ao.id, -- Self-message to create discoverable transaction
        Action = "Agent-Announcement",
        Tags = {
            ["App-Name"] = "ArtworkAgentNetwork",
            ["Agent-Type"] = "ArtAgent", 
            ["Content-Hash"] = ContentHash,
            ["Artwork-Type"] = ArtworkData.type,
            ["Agent-Version"] = Version,
            ["Last-Active"] = tostring(os.time())
        },
        Data = json.encode({
            agentId = AgentId,
            contentHash = ContentHash,
            artworkMetadata = ArtworkData.metadata,
            capabilities = {"duplicate-detection", "peer-communication", "content-analysis"}
        })
    })
end

-- Gossip protocol implementation for peer discovery
function startGossipProtocol()
    -- Schedule periodic gossip rounds
    scheduleGossipRound()
end

function scheduleGossipRound()
    -- In a real implementation, this would use a timer
    -- For AO, we'll handle this through periodic message triggers
    GossipRounds = GossipRounds + 1
    performGossipRound()
end

function performGossipRound()
    -- Select random peers for gossip exchange
    local selectedPeers = selectRandomPeers(3)
    
    for _, peer in ipairs(selectedPeers) do
        ao.send({
            Target = peer.agentId,
            Action = "Gossip-Exchange",
            Data = json.encode({
                sender = AgentId,
                networkView = getNetworkViewSample(5),
                contentHash = ContentHash,
                timestamp = os.time()
            })
        })
    end
end

function selectRandomPeers(count)
    local peers = {}
    local peerList = {}
    
    -- Convert peer table to list
    for agentId, peerInfo in pairs(PeerAgents) do
        if agentId ~= AgentId then -- Don't select self
            table.insert(peerList, peerInfo)
        end
    end
    
    -- Randomly select peers
    for i = 1, math.min(count, #peerList) do
        local index = math.random(#peerList)
        table.insert(peers, peerList[index])
        table.remove(peerList, index)
    end
    
    return peers
end

function getNetworkViewSample(count)
    local sample = {}
    local peerList = {}
    
    for agentId, peerInfo in pairs(PeerAgents) do
        table.insert(peerList, {agentId = agentId, info = peerInfo})
    end
    
    for i = 1, math.min(count, #peerList) do
        local index = math.random(#peerList)
        table.insert(sample, peerList[index])
        table.remove(peerList, index)
    end
    
    return sample
end

-- Initiate duplicate detection across the network
function initiateDuplicateSearch()
    -- Broadcast duplicate detection request
    for agentId, peer in pairs(PeerAgents) do
        ao.send({
            Target = agentId,
            Action = "Duplicate-Check",
            Data = json.encode({
                requestingAgent = AgentId,
                contentHash = ContentHash,
                artworkType = ArtworkData.type,
                timestamp = os.time()
            })
        })
    end
end

-- Message Handlers

-- Handle gossip exchange messages
Handlers.add(
    "GossipExchange",
    Handlers.utils.hasMatchingTag("Action", "Gossip-Exchange"),
    function(msg)
        local gossipData = json.decode(msg.Data)
        
        -- Update peer information
        PeerAgents[gossipData.sender] = {
            agentId = gossipData.sender,
            lastSeen = os.time(),
            contentHash = gossipData.contentHash
        }
        
        -- Merge network view
        for _, peerInfo in ipairs(gossipData.networkView) do
            if not PeerAgents[peerInfo.agentId] then
                PeerAgents[peerInfo.agentId] = peerInfo.info
            end
        end
        
        -- Respond with our network view
        ao.send({
            Target = msg.From,
            Action = "Gossip-Response", 
            Data = json.encode({
                sender = AgentId,
                networkView = getNetworkViewSample(5),
                contentHash = ContentHash,
                timestamp = os.time()
            })
        })
    end
)

-- Handle gossip response messages
Handlers.add(
    "GossipResponse",
    Handlers.utils.hasMatchingTag("Action", "Gossip-Response"),
    function(msg)
        local responseData = json.decode(msg.Data)
        
        -- Update peer information
        PeerAgents[responseData.sender] = {
            agentId = responseData.sender,
            lastSeen = os.time(),
            contentHash = responseData.contentHash
        }
        
        -- Merge network view
        for _, peerInfo in ipairs(responseData.networkView) do
            if not PeerAgents[peerInfo.agentId] then
                PeerAgents[peerInfo.agentId] = peerInfo.info
            end
        end
    end
)

-- Handle duplicate detection requests
Handlers.add(
    "DuplicateCheck",
    Handlers.utils.hasMatchingTag("Action", "Duplicate-Check"),
    function(msg)
        local checkData = json.decode(msg.Data)
        
        -- Compare content hashes
        local similarity = hammingDistance(ContentHash, checkData.contentHash)
        local isDuplicate = similarity <= SimilarityThreshold
        
        -- Send response
        ao.send({
            Target = msg.From,
            Action = "Duplicate-Response",
            Data = json.encode({
                respondingAgent = AgentId,
                requestingAgent = checkData.requestingAgent,
                isDuplicate = isDuplicate,
                similarityScore = similarity,
                artworkId = ArtworkData.id,
                contentHash = ContentHash,
                timestamp = os.time()
            })
        })
        
        -- If duplicate found, wake up both agents
        if isDuplicate then
            wakeUpForDuplicate(msg.From, similarity)
        end
    end
)

-- Handle duplicate detection responses
Handlers.add(
    "DuplicateResponse", 
    Handlers.utils.hasMatchingTag("Action", "Duplicate-Response"),
    function(msg)
        local responseData = json.decode(msg.Data)
        
        if responseData.isDuplicate then
            -- Found a duplicate!
            handleDuplicateFound(responseData)
        end
        
        -- Update peer information
        PeerAgents[responseData.respondingAgent] = {
            agentId = responseData.respondingAgent,
            lastSeen = os.time(),
            contentHash = responseData.contentHash
        }
    end
)

-- Handle new peer announcements
Handlers.add(
    "PeerAnnouncement",
    Handlers.utils.hasMatchingTag("Action", "Agent-Announcement"),
    function(msg)
        local announcementData = json.decode(msg.Data)
        
        -- Add new peer to network
        PeerAgents[announcementData.agentId] = {
            agentId = announcementData.agentId,
            contentHash = announcementData.contentHash,
            lastSeen = os.time(),
            metadata = announcementData.artworkMetadata
        }
        
        -- Automatically check for duplicates with new peer
        local similarity = hammingDistance(ContentHash, announcementData.contentHash)
        if similarity <= SimilarityThreshold then
            wakeUpForDuplicate(announcementData.agentId, similarity)
        end
    end
)

-- Handle wake-up calls for duplicate detection
Handlers.add(
    "WakeUpDuplicate",
    Handlers.utils.hasMatchingTag("Action", "Wake-Up-Duplicate"),
    function(msg)
        local wakeData = json.decode(msg.Data)
        
        -- Process duplicate detection wake-up call
        handleDuplicateFound(wakeData)
    end
)

-- Agent coordination functions
function wakeUpForDuplicate(otherAgentId, similarity)
    -- Wake up the other agent about duplicate
    ao.send({
        Target = otherAgentId,
        Action = "Wake-Up-Duplicate",
        Data = json.encode({
            wakingAgent = AgentId,
            duplicateOf = otherAgentId,
            similarityScore = similarity,
            artworkId = ArtworkData.id,
            contentHash = ContentHash,
            timestamp = os.time()
        })
    })
    
    -- Log duplicate detection locally
    logDuplicateDetection(otherAgentId, similarity)
end

function handleDuplicateFound(duplicateData)
    -- Store duplicate relationship
    if not ArtworkData.duplicates then
        ArtworkData.duplicates = {}
    end
    
    ArtworkData.duplicates[duplicateData.respondingAgent or duplicateData.wakingAgent] = {
        agentId = duplicateData.respondingAgent or duplicateData.wakingAgent,
        similarityScore = duplicateData.similarityScore,
        detectedAt = os.time(),
        artworkId = duplicateData.artworkId
    }
    
    -- Notify coordinator (optional)
    notifyCoordinatorOfDuplicate(duplicateData)
end

function logDuplicateDetection(otherAgentId, similarity)
    ao.send({
        Target = ao.id,
        Action = "Log-Duplicate",
        Data = json.encode({
            agentId = AgentId,
            duplicateAgentId = otherAgentId,
            similarityScore = similarity,
            timestamp = os.time(),
            artworkId = ArtworkData.id
        })
    })
end

function notifyCoordinatorOfDuplicate(duplicateData)
    -- Find coordinator process (if configured)
    if CoordinatorProcess then
        ao.send({
            Target = CoordinatorProcess,
            Action = "Duplicate-Detected",
            Data = json.encode({
                reportingAgent = AgentId,
                duplicateAgent = duplicateData.respondingAgent or duplicateData.wakingAgent,
                similarityScore = duplicateData.similarityScore,
                artworkIds = {ArtworkData.id, duplicateData.artworkId},
                timestamp = os.time()
            })
        })
    end
end

-- Utility functions
function convertToGrayscale(imageData, width, height)
    -- Simplified grayscale conversion for demonstration
    -- In practice, this would properly process image data
    local pixels = {}
    for i = 1, width * height do
        pixels[i] = math.random(0, 255) -- Placeholder
    end
    return pixels
end

function calculateGenericHash(content)
    -- Simple content hash for unknown types
    return tostring(simpleHash(content))
end

function simpleHash(str)
    local hash = 0
    for i = 1, #str do
        hash = hash + string.byte(str, i)
        hash = hash % (2^32)
    end
    return hash
end

function splitWords(text)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word:lower())
    end
    return words
end

-- Heartbeat mechanism
Handlers.add(
    "Heartbeat",
    Handlers.utils.hasMatchingTag("Action", "Heartbeat"),
    function(msg)
        LastHeartbeat = os.time()
        
        -- Respond to heartbeat
        ao.send({
            Target = msg.From,
            Action = "Heartbeat-Response",
            Data = json.encode({
                agentId = AgentId,
                status = "active",
                timestamp = LastHeartbeat,
                contentHash = ContentHash
            })
        })
    end
)

-- Initialization handler
Handlers.add(
    "Initialize", 
    Handlers.utils.hasMatchingTag("Action", "Initialize-Agent"),
    function(msg)
        local initData = json.decode(msg.Data)
        initializeAgent(initData.artworkData)
        
        ao.send({
            Target = msg.From,
            Action = "Agent-Initialized",
            Data = json.encode({
                agentId = AgentId,
                contentHash = ContentHash,
                status = "active"
            })
        })
    end
)