-- art_agent.lua
local json = require("json")

-- Inline APM installer to ensure APUS AI loads properly
local apm_id = "RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU"

function Hexencode(str)
    return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

function Hexdecode(hex)
    return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

function HandleRun(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        ao.send({
            Target = msg.From,
            Data = clean_err,
            Result = "error"
        })
    end
end

local function InstallResponseHandler(msg)
    local from = msg.From
    if not from == apm_id then
        print("Attempt to update from illegal source")
        return
    end

    if not msg.Result == "success" then
        print("Update failed: " .. msg.Data)
        return
    end

    local source = msg.Data
    local version = msg.Version

    if source then
        source = Hexdecode(source)
    end

    local func, err = load(string.format([[
        local function _load()
            %s
        end
        _load()
    ]], source))
    if not func then
        error("Error compiling load function: " .. err)
    end
    func()

    apm._version = version
end

-- State variables
ArtAgent = ArtAgent or {}
ArtAgent.id = ao.id
ArtAgent.title = ""
ArtAgent.icon = "📝"
ArtAgent.text = ""
ArtAgent.text_hash = ""
ArtAgent.analysis = {}
ArtAgent.metrics = {}
ArtAgent.fingerprint = {}
ArtAgent.relationships = {}
ArtAgent.credits_remaining = 5
ArtAgent.initialized = false
ArtAgent.discovery_manager = nil
ArtAgent.session_manager = nil
ArtAgent.llm_apus_process = "A5TeWstBP1mD3FiZoU9JrbFUQ9Xg-hBgxHT7oeEVMr0"
ArtAgent.coordinator_process = ""
ArtAgent.apus_installed = false
ArtAgent.apm_loaded = false

-- Install APM handler
Handlers.once(
    "APM.UpdateResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
    function(msg)
        HandleRun(InstallResponseHandler, msg)
        ArtAgent.apm_loaded = true
        print("APM loaded, installing APUS AI...")
        
        -- Install APUS AI
        Send({
            Target = ao.id,
            Action = "Eval",
            Data = 'apm.install("@apus/ai")'
        })
    end
)

-- Start APM installation
Send({
    Target = apm_id,
    Action = "APM.Update"
})
print("📦 Loading APM...")

-- Handler to detect APUS installation
Handlers.once(
    "✅ Downloaded @apus/ai@1.0.4",
    function(msg)
        if string.match(msg.Data or "", "apus") then
            return true
        end
        return false
    end,
    function(msg)
        -- Load required modules after APUS is installed
        print("apus Installed")
        ApusAI = require('@apus/ai')
        ApusAI_Debug = true
        
        ScholarUtils = require("utils.scholar_utils")
        RelationshipAnalyzer = require("utils.relationship_analyzer")
        DiscoveryManager = require("utils.discovery_manager")
        PromptBuilder = require("utils.prompt_builder")
        SessionManager = require("utils.session_manager")
        ArweaveStorage = require("utils.arweave_storage")
        MetricsConfig = require("config.metrics_config")
        
        ArtAgent.apus_installed = true
        ArtAgent.session_manager = SessionManager.new()
        print("APUS AI and all utils loaded")
        
        -- Initialize if text is already set
        if ArtAgent.text ~= "" then
            ArtAgent.initialize()
        end
    end
)

-- Initialize function
function ArtAgent.initialize()
    if ArtAgent.initialized then return end
    if not ArtAgent.apus_installed then 
        print("Waiting for APUS AI to install...")
        return 
    end
    
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
    
    -- Use 2 credits for analysis
    if ArtAgent.credits_remaining >= 2 then
        ApusAI.infer(prompt, {}, function(err, res)
            if err then
                print("Analysis error: " .. err.message)
                return
            end
            
            -- Parse analysis using scholar_utils
            ArtAgent.analysis = ScholarUtils.parseAnalysis(res.data)
            
            ArtAgent.credits_remaining = ArtAgent.credits_remaining - 2
            ArtAgent.discovery_manager:useArtAgentCredit()
            ArtAgent.discovery_manager:useArtAgentCredit()
            
            print("Analysis complete, extracting metrics...")
            
            -- Extract metrics
            ArtAgent.extractMetrics()
        end)
    else
        print("Insufficient credits for self-analysis")
    end
end

-- Extract metrics from analysis
function ArtAgent.extractMetrics()
    local metrics_prompt = PromptBuilder.buildMetricExtractionPrompt(
        ArtAgent.analysis, 
        ArtAgent.text
    )
    
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
            ArweaveStorage.storeArtwork({
                agent_id = ArtAgent.id,
                title = ArtAgent.title,
                icon = ArtAgent.icon,
                text = ArtAgent.text,
                text_hash = ArtAgent.text_hash,
                analysis = ArtAgent.analysis,
                metrics = ArtAgent.metrics,
                fingerprint = ArtAgent.fingerprint
            })
            
            print("Metrics extracted, registering with coordinator...")
            
            -- Register with coordinator
            ArtAgent.registerWithCoordinator()
            
            -- Start discovery
            ArtAgent.startDiscovery()
        end)
    else
        -- Use external LLM for metrics
        ArtAgent.useExternalLLM(metrics_prompt, "metrics", function(response)
            ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(response)
            ArtAgent.fingerprint = ScholarUtils.createFingerprint(
                ArtAgent.analysis,
                ArtAgent.metrics,
                string.sub(ArtAgent.text, 1, 500)
            )
            
            ArweaveStorage.storeArtwork({
                agent_id = ArtAgent.id,
                title = ArtAgent.title,
                icon = ArtAgent.icon,
                text = ArtAgent.text,
                text_hash = ArtAgent.text_hash,
                analysis = ArtAgent.analysis,
                metrics = ArtAgent.metrics,
                fingerprint = ArtAgent.fingerprint
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
            title = ArtAgent.title,
            icon = ArtAgent.icon,
            text_hash = ArtAgent.text_hash,
            analysis = ArtAgent.analysis,
            metrics = ArtAgent.metrics,
            fingerprint = ArtAgent.fingerprint
        })
    })
end

-- Start peer discovery
function ArtAgent.startDiscovery()
    print("Starting peer discovery...")
    
    -- Request initial random agents from coordinator
    Send({
        Target = ArtAgent.coordinator_process,
        Action = "Get-Random-Agents",
        Data = json.encode({
            requester = ArtAgent.id,
            count = MetricsConfig.DISCOVERY.initial_random_agents
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

-- Compare with peer agents
function ArtAgent.compareWithPeers(peer_agents)
    if ArtAgent.discovery_manager:shouldStop() then
        print("Discovery complete")
        ArtAgent.finalizeDiscovery()
        return
    end
    
    for _, peer in ipairs(peer_agents) do
        if ArtAgent.discovery_manager:shouldStop() then break end
        
        if not ArtAgent.discovery_manager:isExamined(peer.agent_id) then
            ArtAgent.discovery_manager:markExamined(peer.agent_id)
            
            local comparison_prompt = PromptBuilder.buildComparisonPrompt(
                {
                    agent_id = ArtAgent.id,
                    title = ArtAgent.title,
                    analysis = ArtAgent.analysis,
                    metrics = ArtAgent.metrics,
                    fingerprint = ArtAgent.fingerprint,
                    text = ArtAgent.text
                },
                peer
            )
            
            -- Check if should use external LLM
            if ArtAgent.discovery_manager:shouldUseLLMApus() or ArtAgent.credits_remaining < 1 then
                ArtAgent.useExternalLLM(comparison_prompt, "compare-" .. peer.agent_id, function(response)
                    local result = RelationshipAnalyzer.parseRelationship(response)
                    ArtAgent.processComparisonResult(result, peer.agent_id)
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
                    
                    local result = RelationshipAnalyzer.parseRelationship(res.data)
                    ArtAgent.processComparisonResult(result, peer.agent_id)
                end)
            end
        end
    end
end

-- Process comparison result
function ArtAgent.processComparisonResult(result, peer_id)
    if result.type ~= "none" then
        local relationship = {
            agent1 = ArtAgent.id,
            agent2 = peer_id,
            type = result.type,
            score = result.score,
            justification = result.justification,
            similarity = result.similarity or "",
            contrasts = result.contrasts or ""
        }
        
        -- Add to relationships
        table.insert(ArtAgent.relationships, relationship)
        ArtAgent.discovery_manager:addRelationship(relationship)
        
        -- Store to Arweave
        ArweaveStorage.storeRelationship(relationship)
        
        -- Register with coordinator
        Send({
            Target = ArtAgent.coordinator_process,
            Action = "Register-Relationship",
            Data = json.encode(relationship)
        })
        
        -- If sibling/cousin found, explore their network
        if result.type == "sibling" or result.type == "cousin" then
            Send({
                Target = peer_id,
                Action = "Share-Network",
                Data = json.encode({requester = ArtAgent.id})
            })
        end
    end
    
    -- Check if should continue
    if not ArtAgent.discovery_manager:shouldStop() then
        -- Continue discovery
        local next_candidates = ArtAgent.discovery_manager:getNextCandidates(ArtAgent.relationships)
        if #next_candidates > 0 then
            Send({
                Target = ArtAgent.coordinator_process,
                Action = "Get-Agent-Info",
                Data = json.encode({
                    requester = ArtAgent.id,
                    agent_ids = next_candidates
                })
            })
        end
    else
        ArtAgent.finalizeDiscovery()
    end
end

-- Finalize discovery
function ArtAgent.finalizeDiscovery()
    local summary = ArtAgent.discovery_manager:getSummary()
    
    print("Discovery complete!")
    print("Examined: " .. summary.total_examined .. " agents")
    print("Relationships found: " .. summary.total_relationships)
    print("Credits used: " .. summary.art_agent_credits)
    print("External LLM calls: " .. summary.llm_apus_calls)
    
    -- Store report
    ArweaveStorage.storeDiscoveryReport(ArtAgent.id, summary)
    
    -- Notify coordinator
    Send({
        Target = ArtAgent.coordinator_process,
        Action = "Discovery-Complete",
        Data = json.encode({
            agent_id = ArtAgent.id,
            summary = summary
        })
    })
end

-- Handler: Set text and initialize
Handlers.add(
    "Set-Text",
    Handlers.utils.hasMatchingTag("Action", "Set-Text"),
    function(msg)
        ArtAgent.text = msg.Data
        ArtAgent.title = msg.Tags["Title"] or "Untitled"
        ArtAgent.icon = msg.Tags["Icon"] or "📝"
        ArtAgent.coordinator_process = msg.Tags["Coordinator"] or ""
        
        if ArtAgent.apus_installed then
            ArtAgent.initialize()
        else
            print("Waiting for APUS AI to install...")
        end
    end
)

-- Handler: Receive random agents from coordinator
Handlers.add(
    "Random-Agents",
    Handlers.utils.hasMatchingTag("Action", "Random-Agents"),
    function(msg)
        local agents = json.decode(msg.Data)
        ArtAgent.compareWithPeers(agents)
    end
)

-- Handler: Receive specific agent info
Handlers.add(
    "Agent-Info",
    Handlers.utils.hasMatchingTag("Action", "Agent-Info"),
    function(msg)
        local agents = json.decode(msg.Data)
        ArtAgent.compareWithPeers(agents)
    end
)

-- Handler: External LLM response
Handlers.add(
    "Infer-Response",
    Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        local reference = msg["X-Reference"]
        local callback = ArtAgent["callback_" .. reference]
        
        if callback then
            -- Parse response based on type
            local data = msg.Data
            if msg.Code then
                print("LLM error: " .. msg.Code .. " - " .. data)
                return
            end
            
            -- Try to parse JSON response
            local success, parsed = pcall(json.decode, data)
            if success and parsed.result then
                callback(parsed.result)
            else
                callback(data)
            end
            
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
        
        -- Share top relationships (limit from config)
        local top_relationships = {}
        for i = 1, math.min(MetricsConfig.DISCOVERY.network_share_limit, #ArtAgent.relationships) do
            table.insert(top_relationships, {
                peer_id = ArtAgent.relationships[i].agent2
            })
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
                apus_installed = ArtAgent.apus_installed,
                credits_remaining = ArtAgent.credits_remaining,
                relationships_found = #ArtAgent.relationships,
                discovery_status = ArtAgent.discovery_manager and 
                    ArtAgent.discovery_manager:getSummary() or "not started"
            })
        })
    end
)

print("Art Agent Process ID: " .. ao.id)
return ArtAgent