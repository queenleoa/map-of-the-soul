-- art_agent.lua
local json = require("json")
local crypto = require(".crypto")

-- Configuration requires
local MetricsConfig = require("config.metrics_config")
local ProcessConfig = require("config.process_config")

-- Utility requires
local ScholarUtils = require("utils.scholar_utils")
local PromptBuilder = require("utils.prompt_builder")
local RelationshipAnalyzer = require("utils.relationship_analyzer")
local DiscoveryManager = require("utils.discovery_manager")
local GemmaInterface = require("utils.gemma_interface")
local ArweaveStorage = require("utils.arweave_storage")
local SessionManager = require("utils.session_manager")

-- Inline installer for APUS
local function installAPUS()
    local apm_id = "RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU"
    
    function Hexencode(str)
        return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
    end
    
    function Hexdecode(hex)
        return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
    end
    
    local function InstallResponseHandler(msg)
        if not msg.From == apm_id then
            print("Attempt to update from illegal source")
            return
        end
        
        if not msg.Result == "success" then
            print("Update failed: " .. msg.Data)
            return
        end
        
        local source = Hexdecode(msg.Data)
        local func = load(string.format([[
            local function _load()
                %s
            end
            _load()
        ]], source))
        if func then func() end
    end
    
    Handlers.once(
        "APM.UpdateResponse",
        Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
        InstallResponseHandler
    )
    
    Send({
        Target = apm_id,
        Action = "APM.Update"
    })
    print("📦 Loading APM...")
end

-- Agent state
ArtAgent = ArtAgent or {}
ArtAgent.agent_id = ao.id
ArtAgent.title = ""
ArtAgent.icon = "📝"
ArtAgent.text = ""
ArtAgent.text_hash = ""
ArtAgent.analysis = {}
ArtAgent.metrics = {}
ArtAgent.fingerprint = {}
ArtAgent.discovery = nil
ArtAgent.session_manager = SessionManager.new()
ArtAgent.initialized = false
ArtAgent.apus_ready = false
ArtAgent.coordinator_id = ProcessConfig.PROCESSES.coordinator

-- Initialize APUS after APM loads
function ArtAgent.initializeAPUS()
    if ArtAgent.apus_ready then return end
    
    local success = pcall(function()
        apm.install("@apus/ai")
        ApusAI = require("@apus/ai")
        ApusAI_Debug = true
        ArtAgent.apus_ready = true
        print("✅ APUS AI initialized")
    end)
    
    if not success then
        print("⏳ Waiting for APM to load...")
        -- Retry after a delay
        Send({
            Target = ao.id,
            Action = "Retry-APUS-Init",
            ["Delay"] = "5000"
        })
    end
end

-- Initialize agent with artwork text
function ArtAgent.initialize(text, title, icon)
    ArtAgent.text = text
    ArtAgent.title = title or "Untitled"
    ArtAgent.icon = icon or "📝"
    ArtAgent.text_hash = ScholarUtils.hashText(text)
    ArtAgent.discovery = DiscoveryManager.new(ao.id)
    ArtAgent.initialized = true
    
    print("Art Agent initialized: " .. ArtAgent.title)
    print("Text hash: " .. ArtAgent.text_hash)
    
    -- Start self-analysis
    ArtAgent.performSelfAnalysis()
end

-- Perform self-analysis using APUS AI
function ArtAgent.performSelfAnalysis()
    if not ArtAgent.apus_ready then
        print("Waiting for APUS AI...")
        return
    end
    
    print("Starting self-analysis...")
    
    local prompt = PromptBuilder.buildSelfAnalysisPrompt(ArtAgent.text)
    local reference = "self-analysis-" .. os.time()
    
    -- Check if should use free credits or LLM APUS
    if ArtAgent.discovery and ArtAgent.discovery:shouldUseLLMApus() then
        -- Use LLM APUS (external process)
        local request = GemmaInterface.buildLLMApusRequest(prompt, reference)
        Send(request)
        ArtAgent.discovery:useLLMApus()
    else
        -- Use free credits with APUS AI
        ApusAI.infer(prompt, {reference = reference}, function(err, res)
            if err then
                print("Analysis error: " .. (err.message or "unknown"))
                return
            end
            
            -- Parse analysis
            ArtAgent.analysis = ScholarUtils.parseAnalysis(res.data)
            print("Analysis complete")
            
            -- Store session for metric extraction
            if res.session then
                ArtAgent.session_manager:setSession(res.session, "analysis")
            end
            
            -- Continue to metric extraction
            ArtAgent.extractMetrics()
        end)
        
        if ArtAgent.discovery then
            ArtAgent.discovery:useArtAgentCredit()
        end
    end
end

-- Extract metrics from analysis
function ArtAgent.extractMetrics()
    print("Extracting metrics...")
    
    local prompt = PromptBuilder.buildMetricExtractionPrompt(
        ArtAgent.analysis,
        ArtAgent.text
    )
    local reference = "metrics-" .. os.time()
    
    -- Check if should use free credits or LLM APUS
    if ArtAgent.discovery and ArtAgent.discovery:shouldUseLLMApus() then
        -- Use LLM APUS
        local request = GemmaInterface.buildLLMApusRequest(prompt, reference)
        Send(request)
        ArtAgent.discovery:useLLMApus()
    else
        -- Use APUS AI with session if available
        local options = {reference = reference}
        if ArtAgent.session_manager:getSession() then
            options.session = ArtAgent.session_manager:getSession()
        end
        
        ApusAI.infer(prompt, options, function(err, res)
            if err then
                print("Metrics error: " .. (err.message or "unknown"))
                return
            end
            
            -- Parse metrics
            ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(res.data)
            print("Metrics extracted")
            
            -- Create fingerprint
            local text_excerpt = string.sub(ArtAgent.text, 1, 500)
            ArtAgent.fingerprint = ScholarUtils.createFingerprint(
                ArtAgent.analysis,
                ArtAgent.metrics,
                text_excerpt
            )
            
            -- Register with coordinator
            ArtAgent.registerWithCoordinator()
        end)
        
        if ArtAgent.discovery then
            ArtAgent.discovery:useArtAgentCredit()
        end
    end
end

-- Register with coordinator
function ArtAgent.registerWithCoordinator()
    print("Registering with coordinator...")
    
    Send({
        Target = ArtAgent.coordinator_id,
        Action = "Register-Agent",
        Data = json.encode({
            agent_id = ArtAgent.agent_id,
            title = ArtAgent.title,
            icon = ArtAgent.icon,
            text_hash = ArtAgent.text_hash,
            analysis = ArtAgent.analysis,
            metrics = ArtAgent.metrics,
            fingerprint = ArtAgent.fingerprint
        })
    })
    
    -- Store artwork on Arweave
    ArweaveStorage.storeArtwork({
        agent_id = ArtAgent.agent_id,
        title = ArtAgent.title,
        icon = ArtAgent.icon,
        text = ArtAgent.text,
        text_hash = ArtAgent.text_hash,
        analysis = ArtAgent.analysis,
        metrics = ArtAgent.metrics,
        fingerprint = ArtAgent.fingerprint
    })
end

-- Start discovery process
function ArtAgent.startDiscovery()
    print("Starting discovery process...")
    
    -- Request random agents from coordinator
    Send({
        Target = ArtAgent.coordinator_id,
        Action = "Get-Random-Agents",
        Data = json.encode({
            requester = ArtAgent.agent_id,
            count = MetricsConfig.DISCOVERY.initial_random_agents
        })
    })
end

-- Compare with another agent
function ArtAgent.compareWithAgent(other_agent)
    -- Check for duplicate first
    if RelationshipAnalyzer.checkDuplicate(ArtAgent.text_hash, other_agent.text_hash) then
        local relationship = {
            agent1 = ArtAgent.agent_id,
            agent2 = other_agent.agent_id,
            type = "duplicate",
            score = 100,
            justification = "Exact text match",
            peer_id = other_agent.agent_id
        }
        
        ArtAgent.registerRelationship(relationship)
        return
    end
    
    -- Build comparison prompt
    local prompt = PromptBuilder.buildComparisonPrompt(
        {
            agent_id = ArtAgent.agent_id,
            title = ArtAgent.title,
            analysis = ArtAgent.analysis,
            metrics = ArtAgent.metrics,
            fingerprint = ArtAgent.fingerprint,
            text = ArtAgent.text
        },
        other_agent
    )
    
    local reference = "compare-" .. other_agent.agent_id .. "-" .. os.time()
    
    -- Use LLM for comparison
    if ArtAgent.discovery:shouldUseLLMApus() then
        local request = GemmaInterface.buildLLMApusRequest(prompt, reference)
        request["X-Other-Agent"] = other_agent.agent_id
        Send(request)
        ArtAgent.discovery:useLLMApus()
    else
        ApusAI.infer(prompt, {reference = reference}, function(err, res)
            if err then
                print("Comparison error: " .. (err.message or "unknown"))
                return
            end
            
            -- Parse relationship
            local relationship = RelationshipAnalyzer.parseRelationship(res.data)
            relationship.agent1 = ArtAgent.agent_id
            relationship.agent2 = other_agent.agent_id
            relationship.peer_id = other_agent.agent_id
            
            ArtAgent.registerRelationship(relationship)
        end)
        
        ArtAgent.discovery:useArtAgentCredit()
    end
end

-- Register relationship
function ArtAgent.registerRelationship(relationship)
    if relationship.type == "none" then
        print("No relationship with " .. relationship.agent2)
        return
    end
    
    print("Found " .. relationship.type .. " with " .. relationship.agent2)
    
    -- Add to discovery manager
    ArtAgent.discovery:addRelationship(relationship)
    ArtAgent.discovery:markExamined(relationship.agent2)
    
    -- Register with coordinator
    Send({
        Target = ArtAgent.coordinator_id,
        Action = "Register-Relationship",
        Data = json.encode(relationship)
    })
    
    -- Store on Arweave
    ArweaveStorage.storeRelationship(relationship)
    
    -- Check if discovery should stop
    if ArtAgent.discovery:shouldStop() then
        ArtAgent.completeDiscovery()
    else
        -- Continue discovery with related agents
        ArtAgent.continueDiscovery()
    end
end

-- Continue discovery with related agents
function ArtAgent.continueDiscovery()
    local candidates = ArtAgent.discovery:getNextCandidates()
    
    if #candidates > 0 then
        -- Get info about candidate agents
        Send({
            Target = ArtAgent.coordinator_id,
            Action = "Get-Agent-Info",
            Data = json.encode({
                agent_ids = candidates
            })
        })
    else
        -- Get more random agents
        Send({
            Target = ArtAgent.coordinator_id,
            Action = "Get-Random-Agents",
            Data = json.encode({
                requester = ArtAgent.agent_id,
                count = 5
            })
        })
    end
end

-- Complete discovery
function ArtAgent.completeDiscovery()
    local summary = ArtAgent.discovery:getSummary()
    
    print("Discovery complete!")
    print("Total relationships: " .. summary.total_relationships)
    print("Credits used: " .. summary.art_agent_credits)
    print("LLM calls: " .. summary.llm_apus_calls)
    
    -- Notify coordinator
    Send({
        Target = ArtAgent.coordinator_id,
        Action = "Discovery-Complete",
        Data = json.encode({
            agent_id = ArtAgent.agent_id,
            summary = summary
        })
    })
    
    -- Store report
    ArweaveStorage.storeDiscoveryReport(ArtAgent.agent_id, summary)
    
    ArtAgent.discovery.discovery_complete = true
end

-- HANDLERS

-- Initialize with text
Handlers.add(
    "Initialize",
    Handlers.utils.hasMatchingTag("Action", "Initialize"),
    function(msg)
        local data = json.decode(msg.Data)
        ArtAgent.initialize(data.text, data.title, data.icon)
    end
)

-- Retry APUS initialization
Handlers.add(
    "Retry-APUS-Init",
    Handlers.utils.hasMatchingTag("Action", "Retry-APUS-Init"),
    function(msg)
        ArtAgent.initializeAPUS()
    end
)

-- Handle APUS inference response
Handlers.add(
    "Infer-Response",
    Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        -- Check for error
        if msg.Code then
            print("Inference error: " .. msg.Code .. " - " .. (msg.Data or ""))
            return
        end
        
        local reference = msg["X-Reference"] or ""
        
        -- Route based on reference type
        if string.find(reference, "self%-analysis") then
            -- Parse analysis from LLM APUS response
            local result = GemmaInterface.parseLLMApusResponse(msg)
            ArtAgent.analysis = ScholarUtils.parseAnalysis(result)
            print("Analysis complete (LLM)")
            ArtAgent.extractMetrics()
            
        elseif string.find(reference, "metrics") then
            -- Parse metrics from LLM APUS response
            local result = GemmaInterface.parseLLMApusResponse(msg)
            ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(result)
            print("Metrics extracted (LLM)")
            
            -- Create fingerprint
            local text_excerpt = string.sub(ArtAgent.text, 1, 500)
            ArtAgent.fingerprint = ScholarUtils.createFingerprint(
                ArtAgent.analysis,
                ArtAgent.metrics,
                text_excerpt
            )
            
            ArtAgent.registerWithCoordinator()
            
        elseif string.find(reference, "compare") then
            -- Parse relationship from LLM APUS response
            local result = GemmaInterface.parseLLMApusResponse(msg)
            local relationship = RelationshipAnalyzer.parseRelationship(result)
            
            -- Get other agent ID from tag
            local other_agent_id = msg["X-Other-Agent"]
            if other_agent_id then
                relationship.agent1 = ArtAgent.agent_id
                relationship.agent2 = other_agent_id
                relationship.peer_id = other_agent_id
                
                ArtAgent.registerRelationship(relationship)
            end
        end
    end
)

-- Registration result from coordinator
Handlers.add(
    "Registration-Result",
    Handlers.utils.hasMatchingTag("Action", "Registration-Result"),
    function(msg)
        local result = json.decode(msg.Data)
        
        if result.status == "duplicate" then
            print("Duplicate agent detected, original: " .. result.original_agent)
            ArtAgent.completeDiscovery()
        else
            print("Registered with coordinator")
            ArtAgent.startDiscovery()
        end
    end
)

-- Random agents from coordinator
Handlers.add(
    "Random-Agents",
    Handlers.utils.hasMatchingTag("Action", "Random-Agents"),
    function(msg)
        local agents = json.decode(msg.Data)
        
        print("Received " .. #agents .. " agents to examine")
        
        for _, agent in ipairs(agents) do
            if not ArtAgent.discovery:isExamined(agent.agent_id) and
               not ArtAgent.discovery:shouldStop() then
                ArtAgent.compareWithAgent(agent)
            end
        end
    end
)

-- Agent info from coordinator
Handlers.add(
    "Agent-Info",
    Handlers.utils.hasMatchingTag("Action", "Agent-Info"),
    function(msg)
        local agents = json.decode(msg.Data)
        
        for _, agent in ipairs(agents) do
            if not ArtAgent.discovery:isExamined(agent.agent_id) and
               not ArtAgent.discovery:shouldStop() then
                ArtAgent.compareWithAgent(agent)
            end
        end
    end
)

-- Initialize on spawn
print("Art Agent Process: " .. ao.id)
installAPUS()

-- Delay APUS initialization to allow APM to load
Send({
    Target = ao.id,
    Action = "Retry-APUS-Init",
    ["Delay"] = "10000"
})

return ArtAgent