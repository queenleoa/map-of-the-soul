-- art_agent.lua
local json = require("json")
local ScholarUtils = require("utils.scholar_utils")
local RelationshipAnalyzer = require("utils.relationship_analyzer")
local DiscoveryManager = require("utils.discovery_manager")
local PromptBuilder = require("utils.prompt_builder")
local SessionManager = require("utils.session_manager")
local ArweaveStorage = require("utils.arweave_storage")
local GemmaInterface = require("utils.gemma_interface")
local MetricsConfig = require("config.metrics_config")

-- Load APM installer for APUS
local installer = require("installer")

-- State variables
ArtAgent = ArtAgent or {}
ArtAgent.id = ao.id
ArtAgent.text = ArtAgent.text or ""
ArtAgent.text_hash = ""
ArtAgent.analysis = {}
ArtAgent.metrics = {}
ArtAgent.fingerprint = {}
ArtAgent.relationships = {}
ArtAgent.credits_remaining = 5
ArtAgent.initialized = false
ArtAgent.discovery_manager = nil
ArtAgent.session_manager = SessionManager.new()
ArtAgent.llm_apus_process = "A5TeWstBP1mD3FiZoU9JrbFUQ9Xg-hBgxHT7oeEVMr0"
ArtAgent.coordinator_process = "" -- Set this to your coordinator ID

-- Wait for APM to load
Handlers.once(
    "APM.Loaded",
    Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
    function(msg)
        print("APM loaded, installing APUS AI...")
        -- Install APUS AI
        Send({
            Target = ao.id,
            Action = "Eval",
            Data = 'apm.install("@apus/ai")'
        })
    end
)

-- Initialize APUS AI after installation
Handlers.once(
    "APUS.Installed",
    function(msg)
        if string.match(msg.Data or "", "apus") then
            return true
        end
        return false
    end,
    function(msg)
        ApusAI = require('@apus/ai')
        ApusAI_Debug = true
        print("APUS AI installed and ready")
        
        -- Now initialize the art agent
        if ArtAgent.text ~= "" then
            ArtAgent.initialize()
        end
    end
)

-- Initialize function
function ArtAgent.initialize()
    if ArtAgent.initialized then return end
    
    print("Initializing Art Agent...")
    ArtAgent.text_hash = ScholarUtils.hashText(ArtAgent.text)
    ArtAgent.discovery_manager = DiscoveryManager.new(ArtAgent.id)
    
    -- Start self-analysis
    ArtAgent.analyzeSelf()
    ArtAgent.initialized = true
end

-- Self-analysis using own credits
function ArtAgent.analyzeSelf()
    print("Starting self-analysis...")
    
    local prompt = PromptBuilder.buildSelfAnalysisPrompt(ArtAgent.text)
    local session_id = ArtAgent.session_manager:getSession("analysis", ArtAgent.id)
    
    -- Use 2 credits for analysis
    if ArtAgent.credits_remaining >= 2 then
        ApusAI.infer(prompt, {session = session_id}, function(err, res)
            if err then
                print("Analysis error: " .. err.message)
                return
            end
            
            -- Parse analysis
            ArtAgent.analysis = {
                emotional_tone = res.data:match("Emotional Tone[^:]*:%s*([^\n]+)") or "",
                thematic_elements = res.data:match("Thematic Elements[^:]*:%s*([^\n]+)") or "",
                stylistic_features = res.data:match("Stylistic[^:]*:%s*([^\n]+)") or "",
                hidden_insight = res.data:match("Hidden Insight[^:]*:%s*([^\n]+)") or ""
            }
            
            ArtAgent.credits_remaining = ArtAgent.credits_remaining - 2
            ArtAgent.discovery_manager:useArtAgentCredit()
            ArtAgent.discovery_manager:useArtAgentCredit()
            
            -- Extract metrics
            ArtAgent.extractMetrics()
        end)
    else
        print("Insufficient credits for self-analysis")
    end
end

-- Extract metrics from analysis
function ArtAgent.extractMetrics()
    local metrics_prompt = PromptBuilder.buildMetricExtractionPrompt(ArtAgent.analysis)
    
    -- Use 1 credit for metrics
    if ArtAgent.credits_remaining >= 1 then
        ApusAI.infer(metrics_prompt, {}, function(err, res)
            if err then
                print("Metrics extraction error: " .. err.message)
                return
            end
            
            ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(res.data)
            ArtAgent.credits_remaining = ArtAgent.credits_remaining - 1
            ArtAgent.discovery_manager:useArtAgentCredit()
            
            -- Create fingerprint
            ArtAgent.fingerprint = ScholarUtils.createFingerprint(
                ArtAgent.analysis,
                ArtAgent.metrics,
                string.sub(ArtAgent.text, 1, 500)
            )
            
            -- Store to Arweave
            ArweaveStorage.storeAnalysis(ArtAgent.id, {
                fingerprint = ArtAgent.fingerprint,
                analysis = ArtAgent.analysis,
                metrics = ArtAgent.metrics
            })
            
            -- Register with coordinator
            ArtAgent.registerWithCoordinator()
            
            -- Start discovery
            ArtAgent.startDiscovery()
        end)
    else
        -- Use llm_apus for metrics
        ArtAgent.useExternalLLM(metrics_prompt, "metrics", function(metrics)
            ArtAgent.metrics = metrics
            ArtAgent.fingerprint = ScholarUtils.createFingerprint(
                ArtAgent.analysis,
                ArtAgent.metrics,
                string.sub(ArtAgent.text, 1, 500)
            )
            ArweaveStorage.storeAnalysis(ArtAgent.id, {
                fingerprint = ArtAgent.fingerprint,
                analysis = ArtAgent.analysis,
                metrics = ArtAgent.metrics
            })
            ArtAgent.registerWithCoordinator()
            ArtAgent.startDiscovery()
        end)
    end
end

-- Register with coordinator
function ArtAgent.registerWithCoordinator()
    if ArtAgent.coordinator_process == "" then
        print("No coordinator process set")
        return
    end
    
    Send({
        Target = ArtAgent.coordinator_process,
        Action = "Register-Agent",
        Data = json.encode({
            agent_id = ArtAgent.id,
            text_hash = ArtAgent.text_hash,
            fingerprint = ArtAgent.fingerprint,
            analysis = ArtAgent.analysis,
            metrics = ArtAgent.metrics
        })
    })
end

-- Start peer discovery
function ArtAgent.startDiscovery()
    print("Starting peer discovery...")
    
    -- Request initial peers from coordinator
    Send({
        Target = ArtAgent.coordinator_process,
        Action = "Get-Random-Agents",
        Data = json.encode({
            requester = ArtAgent.id,
            count = 15
        })
    })
end

-- Use external LLM when out of credits
function ArtAgent.useExternalLLM(prompt, purpose, callback)
    local reference = "ext-" .. purpose .. "-" .. os.time()
    
    Send({
        Target = ArtAgent.llm_apus_process,
        Action = "Infer",
        ["X-Prompt"] = prompt,
        ["X-Reference"] = reference
    })
    
    -- Store callback for when response arrives
    ArtAgent["callback_" .. reference] = callback
    ArtAgent.discovery_manager:useLLMApus()
end

-- Handler: Receive initial agents from coordinator
Handlers.add(
    "Receive-Initial-Agents",
    Handlers.utils.hasMatchingTag("Action", "Initial-Agents"),
    function(msg)
        local agents = json.decode(msg.Data)
        ArtAgent.compareWithPeers(agents)
    end
)

-- Compare with peer agents
function ArtAgent.compareWithPeers(peer_agents)
    if ArtAgent.discovery_manager:shouldStop() then
        print("Discovery complete")
        ArtAgent.finalizeDiscovery()
        return
    end
    
    -- Batch agents for comparison
    local batches = ScholarUtils.formatBatchComparison(peer_agents, 5)
    
    for _, batch in ipairs(batches) do
        if ArtAgent.discovery_manager:shouldStop() then break end
        
        -- Prepare comparison pairs
        local pairs = {}
        for _, peer in ipairs(batch) do
            if not ArtAgent.discovery_manager:isExamined(peer.agent_id) then
                table.insert(pairs, {
                    agent1 = ArtAgent,
                    agent2 = peer
                })
                ArtAgent.discovery_manager:markExamined(peer.agent_id)
            end
        end
        
        if #pairs > 0 then
            local comparison_prompt = RelationshipAnalyzer.createBatchComparisonPrompt(pairs)
            
            -- Check if should use external LLM
            if ArtAgent.discovery_manager:shouldUseLLMApus() or ArtAgent.credits_remaining < 1 then
                ArtAgent.useExternalLLM(comparison_prompt, "compare", function(results)
                    ArtAgent.processComparisonResults(results, pairs)
                end)
            else
                -- Use own credits
                ApusAI.infer(comparison_prompt, {}, function(err, res)
                    if err then
                        print("Comparison error: " .. err.message)
                        return
                    end
                    
                    ArtAgent.credits_remaining = ArtAgent.credits_remaining - 1
                    ArtAgent.discovery_manager:useArtAgentCredit()
                    
                    local results = RelationshipAnalyzer.parseBatchRelationships(res.data)
                    ArtAgent.processComparisonResults(results, pairs)
                end)
            end
        end
    end
end

-- Process comparison results
function ArtAgent.processComparisonResults(results, pairs)
    for i, result in ipairs(results) do
        if result.type ~= "none" and pairs[i] then
            local relationship = {
                peer_id = pairs[i].agent2.agent_id,
                type = result.type,
                score = result.score,
                justification = result.justification
            }
            
            -- Add to relationships
            table.insert(ArtAgent.relationships, relationship)
            ArtAgent.discovery_manager:addRelationship(relationship)
            
            -- Store to Arweave
            ArweaveStorage.storeRelationship({
                agent1 = ArtAgent.id,
                agent2 = relationship.peer_id,
                type = relationship.type,
                score = relationship.score,
                justification = relationship.justification
            })
            
            -- Notify coordinator
            Send({
                Target = ArtAgent.coordinator_process,
                Action = "Register-Relationship",
                Data = json.encode(relationship)
            })
        end
    end
    
    -- Check if should continue discovery
    if not ArtAgent.discovery_manager:shouldStop() then
        -- Request more peers based on found relationships
        local next_candidates = ArtAgent.discovery_manager:getNextCandidates(ArtAgent.relationships)
        if #next_candidates > 0 then
            -- Request specific agents' networks
            for _, candidate_id in ipairs(next_candidates) do
                Send({
                    Target = candidate_id,
                    Action = "Share-Network",
                    Data = json.encode({requester = ArtAgent.id})
                })
            end
        end
    else
        ArtAgent.finalizeDiscovery()
    end
end

-- Handler: External LLM response
Handlers.add(
    "External-LLM-Response",
    Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        local reference = msg["X-Reference"]
        local callback = ArtAgent["callback_" .. reference]
        
        if callback then
            local data = json.decode(msg.Data)
            callback(data.result or data)
            ArtAgent["callback_" .. reference] = nil
        end
    end
)

-- Handler: Share network with requesting agent
Handlers.add(
    "Share-Network",
    Handlers.utils.hasMatchingTag("Action", "Share-Network"),
    function(msg)
        local request = json.decode(msg.Data)
        
        -- Share top relationships
        local top_relationships = {}
        for i = 1, math.min(5, #ArtAgent.relationships) do
            table.insert(top_relationships, ArtAgent.relationships[i])
        end
        
        Send({
            Target = request.requester,
            Action = "Network-Shared",
            Data = json.encode(top_relationships)
        })
    end
)

-- Handler: Receive shared network
Handlers.add(
    "Network-Shared",
    Handlers.utils.hasMatchingTag("Action", "Network-Shared"),
    function(msg)
        local shared_relationships = json.decode(msg.Data)
        
        -- Extract peer IDs to explore
        local new_peers = {}
        for _, rel in ipairs(shared_relationships) do
            if not ArtAgent.discovery_manager:isExamined(rel.peer_id) then
                table.insert(new_peers, rel.peer_id)
            end
        end
        
        -- Request info about these peers
        if #new_peers > 0 then
            Send({
                Target = ArtAgent.coordinator_process,
                Action = "Get-Agent-Info",
                Data = json.encode({
                    requester = ArtAgent.id,
                    agent_ids = new_peers
                })
            })
        end
    end
)

-- Finalize discovery
function ArtAgent.finalizeDiscovery()
    local summary = ArtAgent.discovery_manager:getSummary()
    
    print("Discovery complete!")
    print("Examined: " .. summary.total_examined .. " agents")
    print("Relationships found: " .. summary.total_relationships)
    print("Credits used: " .. summary.art_agent_credits)
    print("External LLM calls: " .. summary.llm_apus_calls)
    
    -- Notify coordinator of completion
    Send({
        Target = ArtAgent.coordinator_process,
        Action = "Discovery-Complete",
        Data = json.encode({
            agent_id = ArtAgent.id,
            summary = summary,
            relationships = ArtAgent.relationships
        })
    })
end

-- Handler: Set text and initialize
Handlers.add(
    "Set-Text",
    Handlers.utils.hasMatchingTag("Action", "Set-Text"),
    function(msg)
        ArtAgent.text = msg.Data
        ArtAgent.coordinator_process = msg.Tags["Coordinator"] or ""
        
        if ApusAI then
            ArtAgent.initialize()
        else
            print("Waiting for APUS AI to load...")
        end
    end
)

-- Handler: Get status
Handlers.add(
    "Get-Status",
    Handlers.utils.hasMatchingTag("Action", "Get-Status"),
    function(msg)
        Send({
            Target = msg.From,
            Action = "Status",
            Data = json.encode({
                initialized = ArtAgent.initialized,
                credits_remaining = ArtAgent.credits_remaining,
                relationships_found = #ArtAgent.relationships,
                discovery_status = ArtAgent.discovery_manager and 
                    ArtAgent.discovery_manager:getSummary() or "not started"
            })
        })
    end
)

return ArtAgent