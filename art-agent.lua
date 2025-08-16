-- art_agent.lua
local json = require("json")
local crypto = require("crypto")

-- Agent state
ArtworkId = ArtworkId or ""
ContentHash = ContentHash or ""
ContentType = ContentType or "text"
Coordinator = Coordinator or ""
Duplicates = Duplicates or {}
Versions = Versions or {}
PeerAgents = PeerAgents or {}
ContentFingerprint = ContentFingerprint or {}

-- Similarity algorithms
local function calculateTextSimilarity(hash1, hash2)
    -- Simplified similarity based on hash comparison
    -- In production, you'd fetch and compare actual content
    local matches = 0
    for i = 1, math.min(#hash1, #hash2) do
        if hash1:sub(i,i) == hash2:sub(i,i) then
            matches = matches + 1
        end
    end
    return matches / math.max(#hash1, #hash2)
end

local function generateFingerprint(content)
    -- Generate content fingerprint for similarity detection
    -- This is a simplified version - use robust hashing in production
    local words = {}
    for word in content:gmatch("%S+") do
        table.insert(words, word:lower())
    end
    table.sort(words)
    
    -- Create n-gram fingerprints
    local fingerprints = {}
    for i = 1, #words - 2 do
        local ngram = words[i] .. words[i+1] .. words[i+2]
        local fp = crypto.hash("sha256", ngram)
        table.insert(fingerprints, fp:sub(1, 8))
    end
    
    return fingerprints
end

-- Initialize agent
Handlers.add(
    "Initialize",
    Handlers.utils.hasMatchingTag("Action", "Initialize"),
    function(msg)
        ArtworkId = msg.Tags.ArtworkId
        ContentHash = msg.Tags.ContentHash
        ContentType = msg.Tags.ContentType or "text"
        Coordinator = msg.From
        
        -- Load content from Arweave
        ao.send({
            Target = ao.id,
            Action = "LoadContent"
        })
    end
)

-- Load and analyze content
Handlers.add(
    "LoadContent",
    Handlers.utils.hasMatchingTag("Action", "LoadContent"),
    function(msg)
        -- Fetch content from Arweave using ContentHash
        local query = {
            op = "and",
            expr1 = {
                op = "equals",
                expr1 = "Content-Hash",
                expr2 = ContentHash
            }
        }
        
        -- Query Arweave for content
        ao.send({
            Target = "Arweave-Query-Process", -- Hypothetical query service
            Action = "Query",
            Query = json.encode(query),
            Callback = ao.id,
            CallbackAction = "ContentLoaded"
        })
    end
)

-- Process loaded content
Handlers.add(
    "ContentLoaded",
    Handlers.utils.hasMatchingTag("Action", "ContentLoaded"),
    function(msg)
        local content = msg.Data
        
        if ContentType == "text" then
            ContentFingerprint = generateFingerprint(content)
        elseif ContentType == "image" then
            -- For images, use perceptual hashing
            ContentFingerprint = {
                phash = msg.Tags.PHash,
                dhash = msg.Tags.DHash,
                colorHist = msg.Tags.ColorHistogram
            }
        end
        
        -- Store fingerprint for comparison
        ao.send({
            Target = ao.id,
            Action = "StoreFingerprint"
        })
    end
)

-- Discover peer agents
Handlers.add(
    "DiscoverPeers",
    Handlers.utils.hasMatchingTag("Action", "DiscoverPeers"),
    function(msg)
        -- Query Arweave for other art agents
        local query = {
            op = "and",
            expr1 = {
                op = "equals",
                expr1 = "Process-Type",
                expr2 = "ArtAgent"
            },
            expr2 = {
                op = "not-equals",
                expr1 = "Process-Id",
                expr2 = ao.id
            }
        }
        
        -- Query for peer agents
        ao.send({
            Target = "Arweave-Query-Process",
            Action = "Query",
            Query = json.encode(query),
            Callback = ao.id,
            CallbackAction = "PeersDiscovered"
        })
    end
)

-- Handle discovered peers
Handlers.add(
    "PeersDiscovered",
    Handlers.utils.hasMatchingTag("Action", "PeersDiscovered"),
    function(msg)
        local peers = json.decode(msg.Data)
        
        for _, peer in ipairs(peers) do
            if peer.processId ~= ao.id then
                -- Request fingerprint from peer for comparison
                ao.send({
                    Target = peer.processId,
                    Action = "RequestFingerprint",
                    RequesterId = ao.id,
                    RequesterArtwork = ArtworkId
                })
                
                PeerAgents[peer.processId] = {
                    artworkId = peer.artworkId,
                    discovered = msg.Timestamp
                }
            end
        end
    end
)

-- Handle fingerprint requests from peers
Handlers.add(
    "RequestFingerprint",
    Handlers.utils.hasMatchingTag("Action", "RequestFingerprint"),
    function(msg)
        ao.send({
            Target = msg.Tags.RequesterId,
            Action = "FingerprintResponse",
            Fingerprint = json.encode(ContentFingerprint),
            ArtworkId = ArtworkId,
            ContentHash = ContentHash,
            ContentType = ContentType
        })
    end
)

-- Process fingerprint responses and detect duplicates
Handlers.add(
    "FingerprintResponse",
    Handlers.utils.hasMatchingTag("Action", "FingerprintResponse"),
    function(msg)
        local peerFingerprint = json.decode(msg.Tags.Fingerprint)
        local peerId = msg.From
        local peerArtwork = msg.Tags.ArtworkId
        local similarity = 0
        
        if ContentType == "text" then
            -- Compare text fingerprints
            local matches = 0
            local total = 0
            
            for _, fp1 in ipairs(ContentFingerprint) do
                for _, fp2 in ipairs(peerFingerprint) do
                    if fp1 == fp2 then
                        matches = matches + 1
                        break
                    end
                end
                total = total + 1
            end
            
            similarity = matches / math.max(total, #peerFingerprint)
            
        elseif ContentType == "image" then
            -- Compare image hashes
            if peerFingerprint.phash then
                -- Calculate Hamming distance for perceptual hashes
                local distance = 0
                for i = 1, #ContentFingerprint.phash do
                    if ContentFingerprint.phash:sub(i,i) ~= peerFingerprint.phash:sub(i,i) then
                        distance = distance + 1
                    end
                end
                similarity = 1 - (distance / #ContentFingerprint.phash)
            end
        end
        
        -- Threshold for duplicate detection
        local DUPLICATE_THRESHOLD = 0.85
        local VERSION_THRESHOLD = 0.60
        
        if similarity >= DUPLICATE_THRESHOLD then
            -- Found duplicate
            Duplicates[peerId] = {
                artworkId = peerArtwork,
                similarity = similarity,
                timestamp = msg.Timestamp
            }
            
            -- Notify peer about duplicate relationship
            ao.send({
                Target = peerId,
                Action = "DuplicateDetected",
                DuplicateOf = ao.id,
                Similarity = tostring(similarity),
                ArtworkId = ArtworkId
            })
            
        elseif similarity >= VERSION_THRESHOLD then
            -- Found potential version
            Versions[peerId] = {
                artworkId = peerArtwork,
                similarity = similarity,
                timestamp = msg.Timestamp
            }
            
            -- Notify peer about version relationship
            ao.send({
                Target = peerId,
                Action = "VersionDetected",
                VersionOf = ao.id,
                Similarity = tostring(similarity),
                ArtworkId = ArtworkId
            })
        end
    end
)

-- Handle duplicate detection notification
Handlers.add(
    "DuplicateDetected",
    Handlers.utils.hasMatchingTag("Action", "DuplicateDetected"),
    function(msg)
        local duplicateId = msg.Tags.DuplicateOf
        local similarity = tonumber(msg.Tags.Similarity)
        
        -- Update local state
        Duplicates[duplicateId] = {
            artworkId = msg.Tags.ArtworkId,
            similarity = similarity,
            timestamp = msg.Timestamp,
            mutual = true
        }
        
        -- Log duplicate relationship
        print("Duplicate detected with " .. msg.Tags.ArtworkId .. " (similarity: " .. similarity .. ")")
        
        -- Store relationship on Arweave
        ao.send({
            Target = ao.id,
            Action = "StoreDuplicateRelation",
            DuplicateId = duplicateId,
            Similarity = tostring(similarity)
        })
    end
)

-- Handle version detection notification
Handlers.add(
    "VersionDetected",
    Handlers.utils.hasMatchingTag("Action", "VersionDetected"),
    function(msg)
        local versionId = msg.Tags.VersionOf
        local similarity = tonumber(msg.Tags.Similarity)
        
        -- Update local state
        Versions[versionId] = {
            artworkId = msg.Tags.ArtworkId,
            similarity = similarity,
            timestamp = msg.Timestamp,
            mutual = true
        }
        
        print("Version detected with " .. msg.Tags.ArtworkId .. " (similarity: " .. similarity .. ")")
    end
)

-- Query handler for duplicate information
Handlers.add(
    "QueryDuplicates",
    Handlers.utils.hasMatchingTag("Action", "QueryDuplicates"),
    function(msg)
        local response = {
            artworkId = ArtworkId,
            duplicates = Duplicates,
            versions = Versions,
            totalDuplicates = 0,
            totalVersions = 0
        }
        
        for _ in pairs(Duplicates) do
            response.totalDuplicates = response.totalDuplicates + 1
        end
        
        for _ in pairs(Versions) do
            response.totalVersions = response.totalVersions + 1
        end
        
        ao.send({
            Target = msg.From,
            Action = "DuplicatesResponse",
            Data = json.encode(response)
        })
    end
)

-- Periodic peer discovery
Handlers.add(
    "ScheduledDiscovery",
    Handlers.utils.hasMatchingTag("Action", "Cron"),
    function(msg)
        -- Periodically discover new peers
        ao.send({
            Target = ao.id,
            Action = "DiscoverPeers"
        })
    end
)