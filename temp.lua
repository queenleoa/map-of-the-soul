-- ============================================
-- PART 1: MINIMAL COORDINATOR (coordinator.lua)
-- ============================================
-- Save as coordinator.lua and load with: .load coordinator.lua

local json = require("json")

-- Coordinator state (minimal - only spawning)
Coordinator = Coordinator or {
    spawned_agents = {},
    agent_count = 0
}

-- Configuration
Config = {
    agent_module = "REPLACE_WITH_AGENT_MODULE_ID", -- You'll get this after deploying agent template
    scheduler = "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA" -- Default scheduler
}

-- Handler for spawning new art agents
Handlers.add("SpawnArtAgent",
    Handlers.utils.hasMatchingTag("Action", "SpawnAgent"),
    function(msg)
        local artwork_data = json.decode(msg.Data)
        
        -- Spawn process with initial data
        local spawn_data = json.encode({
            artwork_id = artwork_data.id,
            content = artwork_data.content,
            content_type = artwork_data.content_type or "text"
        })
        
        -- Create new agent process
        local agent_id = Spawn(Config.agent_module, {
            Data = spawn_data,
            Tags = {
                {name = "Type", value = "ArtAgent"},
                {name = "ArtworkID", value = artwork_data.id}
            }
        })
        
        -- Record spawned agent
        Coordinator.spawned_agents[agent_id] = {
            artwork_id = artwork_data.id,
            spawned_at = os.time()
        }
        Coordinator.agent_count = Coordinator.agent_count + 1
        
        -- Return agent ID to caller
        ao.send({
            Target = msg.From,
            Action = "AgentSpawned",
            Data = json.encode({
                agent_id = agent_id,
                artwork_id = artwork_data.id,
                status = "spawned"
            })
        })
        
        print("Spawned agent " .. agent_id .. " for artwork " .. artwork_data.id)
    end
)

-- Status check
Handlers.add("CoordinatorStatus",
    Handlers.utils.hasMatchingTag("Action", "Status"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "StatusResponse",
            Data = json.encode({
                total_agents = Coordinator.agent_count,
                agents = Coordinator.spawned_agents
            })
        })
    end
)

print("Coordinator initialized. Ready to spawn art agents.")

-- ============================================
-- PART 2: ART AGENT WITH DISCOVERY (art_agent.lua)  
-- ============================================
-- Save as art_agent.lua and load with: .load art_agent.lua

local json = require("json")
local crypto = require(".crypto")

-- Agent state
ArtAgent = ArtAgent or {
    initialized = false,
    artwork_id = nil,
    content = nil,
    content_hash = nil,
    content_features = {},
    discovered_peers = {},
    confirmed_duplicates = {},
    gossip_known_peers = {}
}

-- Configuration
AgentConfig = {
    similarity_threshold = 0.8,
    hash_distance_threshold = 4,
    gossip_interval = 30,
    discovery_interval = 20
}

-- ============================================
-- CORE FUNCTIONS
-- ============================================

-- Simple hash function for content
function calculate_hash(content)
    if not content then return 0 end
    local hash = 5381
    for i = 1, #content do
        hash = ((hash * 33) + string.byte(content, i)) % 2147483647
    end
    return hash
end

-- SimHash implementation for similarity
function simhash(text, hash_size)
    hash_size = hash_size or 64
    local weights = {}
    for i = 1, hash_size do weights[i] = 0 end
    
    -- Process each word
    for word in string.gmatch(string.lower(text), "%w+") do
        local word_hash = calculate_hash(word)
        for i = 1, hash_size do
            if word_hash % 2 == 1 then
                weights[i] = weights[i] + 1
            else
                weights[i] = weights[i] - 1
            end
            word_hash = math.floor(word_hash / 2)
        end
    end
    
    -- Generate final hash
    local result = 0
    for i = 1, hash_size do
        if weights[i] > 0 then
            result = result + (2 ^ (i - 1))
        end
    end
    return result
end

-- Hamming distance between two hashes
function hamming_distance(hash1, hash2)
    local xor = hash1 ~ hash2
    local distance = 0
    while xor > 0 do
        distance = distance + (xor % 2)
        xor = math.floor(xor / 2)
    end
    return distance
end

-- Jaccard similarity for text
function jaccard_similarity(text1, text2)
    local set1, set2 = {}, {}
    
    -- Tokenize first text
    for word in string.gmatch(string.lower(text1), "%w+") do
        set1[word] = true
    end
    
    -- Tokenize second text
    for word in string.gmatch(string.lower(text2), "%w+") do
        set2[word] = true
    end
    
    -- Calculate intersection and union
    local intersection, union = 0, {}
    for word in pairs(set1) do
        union[word] = true
        if set2[word] then
            intersection = intersection + 1
        end
    end
    for word in pairs(set2) do
        union[word] = true
    end
    
    local union_size = 0
    for _ in pairs(union) do
        union_size = union_size + 1
    end
    
    return union_size == 0 and 0 or intersection / union_size
end

-- Extract content features
function extract_features(content)
    local word_count = 0
    for _ in string.gmatch(content, "%w+") do
        word_count = word_count + 1
    end
    
    return {
        simhash = simhash(content),
        word_count = word_count,
        char_count = #content,
        hash_prefix = string.sub(tostring(calculate_hash(content)), 1, 6)
    }
end

-- ============================================
-- DISCOVERY MECHANISMS
-- ============================================

-- 1. ARWEAVE TAG-BASED DISCOVERY
function announce_via_tags()
    -- Announce existence with searchable tags
    ao.send({
        Target = ao.id,
        Action = "AgentAnnouncement",
        Data = json.encode({
            agent_id = ao.id,
            artwork_id = ArtAgent.artwork_id,
            content_hash = ArtAgent.content_hash,
            features = ArtAgent.content_features
        }),
        Tags = {
            {name = "Protocol", value = "ArtworkDuplicateDetection"},
            {name = "AgentType", value = "ArtProcessor"},
            {name = "ContentHash", value = tostring(ArtAgent.content_hash)},
            {name = "HashPrefix", value = ArtAgent.content_features.hash_prefix},
            {name = "WordCountRange", value = tostring(math.floor(ArtAgent.content_features.word_count / 100) * 100)}
        }
    })
    print("Announced via Arweave tags")
end

-- 2. CONTENT-BASED DISCOVERY
function discover_by_content_similarity()
    -- Look for agents with similar content characteristics
    local prefix = ArtAgent.content_features.hash_prefix
    local word_range = math.floor(ArtAgent.content_features.word_count / 100) * 100
    
    -- Query for similar content
    Send({
        Target = ao.id,
        Action = "QuerySimilarAgents",
        Tags = {
            {name = "Protocol", value = "ArtworkDuplicateDetection"},
            {name = "HashPrefix", value = prefix},
            {name = "WordCountRange", value = tostring(word_range)}
        }
    })
end

-- 3. GOSSIP PROTOCOL
function initiate_gossip()
    -- Share known peers with a random peer
    local peer_list = {}
    for peer_id, _ in pairs(ArtAgent.discovered_peers) do
        table.insert(peer_list, peer_id)
    end
    
    if #peer_list > 0 then
        -- Pick random peer
        local random_peer = peer_list[math.random(#peer_list)]
        
        -- Send gossip
        ao.send({
            Target = random_peer,
            Action = "GossipUpdate",
            Data = json.encode({
                from_agent = ao.id,
                known_peers = ArtAgent.gossip_known_peers,
                my_features = ArtAgent.content_features
            })
        })
    end
end

-- Combined discovery function
function discover_peers()
    print("Starting peer discovery...")
    
    -- Method 1: Query by tags
    announce_via_tags()
    
    -- Method 2: Content-based search
    discover_by_content_similarity()
    
    -- Method 3: Gossip (if we know any peers)
    if next(ArtAgent.discovered_peers) then
        initiate_gossip()
    end
end

-- ============================================
-- DUPLICATE DETECTION
-- ============================================

function check_duplicate_with_peer(peer_id, peer_features)
    -- Quick hash distance check
    local distance = hamming_distance(
        ArtAgent.content_features.simhash,
        peer_features.simhash
    )
    
    if distance <= AgentConfig.hash_distance_threshold then
        -- Potential duplicate, request full comparison
        ao.send({
            Target = peer_id,
            Action = "RequestFullComparison",
            Data = json.encode({
                requester_id = ao.id,
                requester_features = ArtAgent.content_features,
                initial_distance = distance
            })
        })
        print("Potential duplicate found with " .. peer_id .. ", distance: " .. distance)
    end
end

-- ============================================
-- MESSAGE HANDLERS
-- ============================================

-- Initialize agent when spawned
Handlers.add("Initialize",
    function(msg)
        return not ArtAgent.initialized and msg.Data
    end,
    function(msg)
        local init_data = json.decode(msg.Data)
        
        ArtAgent.artwork_id = init_data.artwork_id
        ArtAgent.content = init_data.content
        ArtAgent.content_hash = calculate_hash(init_data.content)
        ArtAgent.content_features = extract_features(init_data.content)
        ArtAgent.initialized = true
        
        print("Agent initialized for artwork: " .. ArtAgent.artwork_id)
        print("Content hash: " .. ArtAgent.content_hash)
        print("SimHash: " .. ArtAgent.content_features.simhash)
        
        -- Start discovery after initialization
        discover_peers()
        
        -- Schedule periodic discovery
        ao.send({
            Target = ao.id,
            Action = "PeriodicDiscovery",
            Delay = AgentConfig.discovery_interval
        })
    end
)

-- Handle discovery of new peers via announcement
Handlers.add("PeerDiscovered",
    Handlers.utils.hasMatchingTag("Action", "AgentAnnouncement"),
    function(msg)
        if msg.From ~= ao.id then
            local peer_data = json.decode(msg.Data)
            
            -- Add to discovered peers
            ArtAgent.discovered_peers[msg.From] = {
                artwork_id = peer_data.artwork_id,
                features = peer_data.features,
                discovered_at = os.time()
            }
            
            -- Add to gossip network
            ArtAgent.gossip_known_peers[msg.From] = true
            
            print("Discovered peer: " .. msg.From)
            
            -- Check for duplicate
            check_duplicate_with_peer(msg.From, peer_data.features)
        end
    end
)

-- Handle gossip updates
Handlers.add("HandleGossip",
    Handlers.utils.hasMatchingTag("Action", "GossipUpdate"),
    function(msg)
        local gossip_data = json.decode(msg.Data)
        
        -- Add sender to known peers
        if msg.From ~= ao.id then
            ArtAgent.gossip_known_peers[msg.From] = true
            
            -- Learn about new peers from gossip
            for peer_id, _ in pairs(gossip_data.known_peers) do
                if peer_id ~= ao.id and not ArtAgent.discovered_peers[peer_id] then
                    -- New peer discovered via gossip!
                    ArtAgent.gossip_known_peers[peer_id] = true
                    
                    -- Introduce ourselves
                    ao.send({
                        Target = peer_id,
                        Action = "PeerIntroduction",
                        Data = json.encode({
                            from_agent = ao.id,
                            artwork_id = ArtAgent.artwork_id,
                            features = ArtAgent.content_features,
                            introduced_by = msg.From
                        })
                    })
                    print("Discovered " .. peer_id .. " via gossip from " .. msg.From)
                end
            end
        end
    end
)

-- Handle peer introductions
Handlers.add("HandleIntroduction",
    Handlers.utils.hasMatchingTag("Action", "PeerIntroduction"),
    function(msg)
        local intro_data = json.decode(msg.Data)
        
        if msg.From ~= ao.id and not ArtAgent.discovered_peers[msg.From] then
            -- Add new peer
            ArtAgent.discovered_peers[msg.From] = {
                artwork_id = intro_data.artwork_id,
                features = intro_data.features,
                discovered_at = os.time(),
                introduced_by = intro_data.introduced_by
            }
            
            print("Introduced to " .. msg.From .. " by " .. (intro_data.introduced_by or "direct"))
            
            -- Check for duplicate
            check_duplicate_with_peer(msg.From, intro_data.features)
            
            -- Send acknowledgment
            ao.send({
                Target = msg.From,
                Action = "IntroductionAck",
                Data = json.encode({
                    from_agent = ao.id,
                    features = ArtAgent.content_features
                })
            })
        end
    end
)

-- Handle full comparison requests
Handlers.add("HandleComparisonRequest",
    Handlers.utils.hasMatchingTag("Action", "RequestFullComparison"),
    function(msg)
        local request_data = json.decode(msg.Data)
        
        -- Calculate Jaccard similarity
        ao.send({
            Target = request_data.requester_id,
            Action = "ComparisonResult",
            Data = json.encode({
                from_agent = ao.id,
                artwork_id = ArtAgent.artwork_id,
                content_sample = string.sub(ArtAgent.content, 1, 500), -- First 500 chars
                full_content = ArtAgent.content
            })
        })
    end
)

-- Handle comparison results
Handlers.add("HandleComparisonResult",
    Handlers.utils.hasMatchingTag("Action", "ComparisonResult"),
    function(msg)
        local result_data = json.decode(msg.Data)
        
        -- Calculate detailed similarity
        local similarity = jaccard_similarity(ArtAgent.content, result_data.full_content)
        
        if similarity >= AgentConfig.similarity_threshold then
            -- Confirmed duplicate!
            ArtAgent.confirmed_duplicates[msg.From] = {
                artwork_id = result_data.artwork_id,
                similarity_score = similarity,
                confirmed_at = os.time()
            }
            
            print("DUPLICATE CONFIRMED with " .. msg.From)
            print("Similarity score: " .. similarity)
            
            -- Notify both agents
            ao.send({
                Target = msg.From,
                Action = "DuplicateConfirmed",
                Data = json.encode({
                    from_agent = ao.id,
                    artwork_id = ArtAgent.artwork_id,
                    similarity = similarity
                })
            })
        else
            print("Not duplicate with " .. msg.From .. ", similarity: " .. similarity)
        end
    end
)

-- Handle duplicate confirmations
Handlers.add("HandleDuplicateConfirmation",
    Handlers.utils.hasMatchingTag("Action", "DuplicateConfirmed"),
    function(msg)
        local confirm_data = json.decode(msg.Data)
        
        -- Record the duplicate
        ArtAgent.confirmed_duplicates[msg.From] = {
            artwork_id = confirm_data.artwork_id,
            similarity_score = confirm_data.similarity,
            confirmed_at = os.time()
        }
        
        print("Duplicate confirmation received from " .. msg.From)
    end
)

-- Periodic discovery
Handlers.add("PeriodicDiscovery",
    Handlers.utils.hasMatchingTag("Action", "PeriodicDiscovery"),
    function(msg)
        discover_peers()
        
        -- Schedule next discovery
        ao.send({
            Target = ao.id,
            Action = "PeriodicDiscovery",
            Delay = AgentConfig.discovery_interval
        })
    end
)

-- Periodic gossip
Handlers.add("PeriodicGossip",
    Handlers.utils.hasMatchingTag("Action", "PeriodicGossip"),
    function(msg)
        initiate_gossip()
        
        -- Schedule next gossip
        ao.send({
            Target = ao.id,
            Action = "PeriodicGossip",
            Delay = AgentConfig.gossip_interval
        })
    end
)

-- Status report
Handlers.add("StatusReport",
    Handlers.utils.hasMatchingTag("Action", "Status"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "StatusResponse",
            Data = json.encode({
                agent_id = ao.id,
                artwork_id = ArtAgent.artwork_id,
                content_hash = ArtAgent.content_hash,
                discovered_peers = ArtAgent.discovered_peers,
                confirmed_duplicates = ArtAgent.confirmed_duplicates,
                features = ArtAgent.content_features
            })
        })
    end
)

print("Art Agent loaded. Waiting for initialization...")

-- ============================================
-- PART 3: TEST HARNESS (test_system.lua)
-- ============================================
-- Save as test_system.lua and run with: .load test_system.lua

local json = require("json")

-- Test documents with varying similarity
TestDocuments = {
    -- Identical documents
    doc1 = {
        id = "doc1",
        content = "The quick brown fox jumps over the lazy dog. This is a sample document for testing duplicate detection.",
        content_type = "text"
    },
    doc2 = {
        id = "doc2", 
        content = "The quick brown fox jumps over the lazy dog. This is a sample document for testing duplicate detection.",
        content_type = "text"
    },
    -- Similar document
    doc3 = {
        id = "doc3",
        content = "The quick brown fox jumps over the lazy dog. This is a sample text for testing duplicate finding.",
        content_type = "text"
    },
    -- Different document
    doc4 = {
        id = "doc4",
        content = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Completely different content here.",
        content_type = "text"
    }
}

-- Test runner
TestRunner = {
    coordinator_id = nil,
    spawned_agents = {},
    test_results = {}
}

-- Initialize test environment
function setup_test()
    print("=== SETTING UP TEST ENVIRONMENT ===")
    
    -- Note: You need to have the coordinator already running
    -- Set this to your coordinator's process ID
    TestRunner.coordinator_id = "YOUR_COORDINATOR_ID" -- REPLACE THIS
    
    if TestRunner.coordinator_id == "YOUR_COORDINATOR_ID" then
        print("ERROR: Please set the coordinator ID first!")
        return false
    end
    
    print("Using coordinator: " .. TestRunner.coordinator_id)
    return true
end

-- Spawn test agents
function spawn_test_agents()
    print("\n=== SPAWNING TEST AGENTS ===")
    
    for doc_id, doc_data in pairs(TestDocuments) do
        ao.send({
            Target = TestRunner.coordinator_id,
            Action = "SpawnAgent",
            Data = json.encode(doc_data)
        })
        print("Requested spawn for " .. doc_id)
        
        -- Small delay between spawns
        os.execute("sleep 1")
    end
end

-- Check agent status
function check_agent_status(agent_id)
    ao.send({
        Target = agent_id,
        Action = "Status"
    })
end

-- Monitor duplicates
function monitor_duplicates()
    print("\n=== MONITORING DUPLICATE DETECTION ===")
    
    -- Query each agent for their status
    for _, agent_id in pairs(TestRunner.spawned_agents) do
        check_agent_status(agent_id)
    end
end

-- Run complete test
function run_test()
    if not setup_test() then
        return
    end
    
    spawn_test_agents()
    
    print("\nWaiting 10 seconds for agents to discover each other...")
    os.execute("sleep 10")
    
    monitor_duplicates()
    
    print("\n=== TEST COMPLETE ===")
    print("Check agent responses for duplicate detection results")
end

-- Handler to receive agent spawn confirmations
Handlers.add("AgentSpawnConfirmed",
    Handlers.utils.hasMatchingTag("Action", "AgentSpawned"),
    function(msg)
        local spawn_data = json.decode(msg.Data)
        TestRunner.spawned_agents[spawn_data.artwork_id] = spawn_data.agent_id
        print("Agent spawned: " .. spawn_data.agent_id .. " for " .. spawn_data.artwork_id)
    end
)

-- Handler to receive status responses
Handlers.add("StatusReceived",
    Handlers.utils.hasMatchingTag("Action", "StatusResponse"),
    function(msg)
        local status = json.decode(msg.Data)
        
        print("\n--- Agent Status ---")
        print("Agent: " .. (status.agent_id or "unknown"))
        print("Artwork: " .. (status.artwork_id or "unknown"))
        
        if status.discovered_peers then
            local peer_count = 0
            for _ in pairs(status.discovered_peers) do
                peer_count = peer_count + 1
            end
            print("Discovered peers: " .. peer_count)
        end
        
        if status.confirmed_duplicates then
            print("Confirmed duplicates:")
            for peer_id, dup_info in pairs(status.confirmed_duplicates) do
                print("  - " .. dup_info.artwork_id .. " (similarity: " .. dup_info.similarity_score .. ")")
            end
        end
    end
)

print("Test harness loaded. Run 'run_test()' to start testing")

-- ============================================
-- PART 4: UTILITY FUNCTIONS (utils.lua)
-- ============================================
-- Save as utils.lua for helper functions

-- JSON encode/decode wrapper
function safe_json_encode(data)
    local success, result = pcall(json.encode, data)
    return success and result or "{}"
end

function safe_json_decode(str)
    local success, result = pcall(json.decode, str)
    return success and result or {}
end

-- Print table for debugging
function print_table(t, indent)
    indent = indent or ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indent .. k .. ":")
            print_table(v, indent .. "  ")
        else
            print(indent .. k .. ": " .. tostring(v))
        end
    end
end

-- Generate correlation ID
function generate_correlation_id()
    return "corr_" .. os.time() .. "_" .. math.random(10000, 99999)
end

print("Utilities loaded")