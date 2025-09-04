-- art_agent.lua
local json = require("json")

-- Inline installer for APM (required for APUS)
local function installAPM()
    local apm_id = "RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU"
    
    function Hexencode(str)
        return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
    end
    
    function Hexdecode(hex)
        return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
    end
    
    Handlers.once(
        "APM.UpdateResponse",
        Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
        function(msg)
            if msg.From ~= apm_id then
                print("Attempt to update from illegal source")
                return
            end
            
            if msg.Result ~= "success" then
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
            if func then 
                func()
                print("APM loaded successfully")
                -- Now install APUS
                print("Installing APUS AI...")
                apm.install("@apus/ai")
            end
        end
    )
    
    Send({
        Target = apm_id,
        Action = "APM.Update"
    })
    print("Loading APM...")
end

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
ArtAgent.text_ready = false

-- APUS detection handler (from working version)
Handlers.add(
    "APUS.Check",
    function(msg)
        local data = msg.Data or ""
        if string.match(data, "Downloaded @apus/ai") or
           string.match(data, "apus/ai@") or
           string.match(data, "Successfully installed") or
           (string.match(data, "✅") and string.match(data, "apus")) then
            return true
        end
        return false
    end,
    function(msg)
        if not ArtAgent.apus_ready then
            print("APUS AI detected as installed")
            
            local success = pcall(function()
                ApusAI = require('@apus/ai')
                ApusAI_Debug = true
            end)
            
            if success then
                ArtAgent.apus_ready = true
                print("✅ APUS AI ready!")
                
                -- Check if text was already set and start analysis
                if ArtAgent.text_ready and not ArtAgent.initialized then
                    ArtAgent.initialize(ArtAgent.text, ArtAgent.title, ArtAgent.icon)
                end
            else
                print("⚠️ APUS require failed, will retry when needed")
            end
        end
    end
)

-- Initialize agent with artwork text
function ArtAgent.initialize(text, title, icon)
    if ArtAgent.initialized then return end
    
    -- Try to load APUS if not ready
    if not ArtAgent.apus_ready then
        local success = pcall(function()
            ApusAI = require('@apus/ai')
            ApusAI_Debug = true
        end)
        if success then
            ArtAgent.apus_ready = true
            print("APUS AI loaded!")
        else
            print("APUS not ready yet, will retry when available")
            ArtAgent.text_ready = true
            ArtAgent.text = text
            ArtAgent.title = title or "Untitled"
            ArtAgent.icon = icon or "📝"
            return
        end
    end
    
    ArtAgent.text = text
    ArtAgent.title = title or "Untitled"
    ArtAgent.icon = icon or "📝"
    ArtAgent.text_hash = ScholarUtils.hashText(text)
    ArtAgent.discovery = DiscoveryManager.new(ao.id)
    ArtAgent.initialized = true
    
    print("Art Agent initialized: " .. ArtAgent.title)
    print("Text hash: " .. ArtAgent.text_hash)
    
    -- Start analysis immediately
    ArtAgent.performSelfAnalysis()
end

-- Perform self-analysis using APUS AI
function ArtAgent.performSelfAnalysis()
    if not ArtAgent.apus_ready or not ArtAgent.initialized then
        print("Not ready for analysis yet")
        return
    end
    
    print("Starting self-analysis...")
    
    local prompt = PromptBuilder.buildSelfAnalysisPrompt(ArtAgent.text)
    local reference = "self-analysis-" .. os.time()
    
    -- Check if should use LLM APUS
    if ArtAgent.discovery and ArtAgent.discovery:shouldUseLLMApus() then
        local request = GemmaInterface.buildLLMApusRequest(prompt, reference)
        Send(request)
        ArtAgent.discovery:useLLMApus()
    else
        -- Use APUS AI
        ApusAI.infer(prompt, {reference = reference}, function(err, res)
            if err then
                print("Analysis error: " .. (err.message or "unknown"))
                return
            end
            
            -- Parse analysis
            ArtAgent.analysis = ScholarUtils.parseAnalysis(res.data)
            print("Analysis complete")
            
            -- Store session
            if res.session then
                ArtAgent.session_manager:setSession(res.session, "analysis")
            end
            
            -- Continue to metrics
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
    
    if ArtAgent.discovery and ArtAgent.discovery:shouldUseLLMApus() then
        local request = GemmaInterface.buildLLMApusRequest(prompt, reference)
        Send(request)
        ArtAgent.discovery:useLLMApus()
    else
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
            fingerprint = ArtAgent.fingerprint,
            text = ArtAgent.text  -- Include full text for comparisons
        })
    })
    
    -- Store on Arweave
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

-- Start discovery
function ArtAgent.startDiscovery()
    print("Starting discovery...")
    
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
    -- Check duplicate first
    if RelationshipAnalyzer.checkDuplicate(ArtAgent.text_hash, other_agent.text_hash) then
        local relationship = {
            agent1 = ArtAgent.agent_id,
            agent2 = other_agent.agent_id,
            type = "duplicate",
            score = 100,
            justification = "Exact text match",
            similarity = "Identical text",
            contrasts = "None",
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
    
    if ArtAgent.discovery and ArtAgent.discovery:shouldUseLLMApus() then
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
            
            local relationship = RelationshipAnalyzer.parseRelationship(res.data)
            relationship.agent1 = ArtAgent.agent_id
            relationship.agent2 = other_agent.agent_id
            relationship.peer_id = other_agent.agent_id
            
            ArtAgent.registerRelationship(relationship)
        end)
        
        if ArtAgent.discovery then
            ArtAgent.discovery:useArtAgentCredit()
        end
    end
end

-- Register relationship
function ArtAgent.registerRelationship(relationship)
    if relationship.type == "none" then
        print("No relationship with " .. relationship.agent2)
        ArtAgent.discovery:markExamined(relationship.agent2)
        
        -- Continue discovery
        if not ArtAgent.discovery:shouldStop() then
            ArtAgent.continueDiscovery()
        else
            ArtAgent.completeDiscovery()
        end
        return
    end
    
    print("Found " .. relationship.type .. " with " .. relationship.agent2)
    
    -- Add to discovery
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
    
    -- Check if should continue
    if ArtAgent.discovery:shouldStop() then
        ArtAgent.completeDiscovery()
    else
        ArtAgent.continueDiscovery()
    end
end

-- Continue discovery
function ArtAgent.continueDiscovery()
    local candidates = ArtAgent.discovery:getNextCandidates()
    
    if #candidates > 0 then
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
    
    Send({
        Target = ArtAgent.coordinator_id,
        Action = "Discovery-Complete",
        Data = json.encode({
            agent_id = ArtAgent.agent_id,
            summary = summary
        })
    })
    
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
        
        -- Save text data
        ArtAgent.text = data.text
        ArtAgent.title = data.title or "Untitled"
        ArtAgent.icon = data.icon or "📝"
        ArtAgent.text_ready = true
        
        print("Text received: " .. ArtAgent.title)
        
        -- Try to initialize (will wait for APUS if not ready)
        ArtAgent.initialize(data.text, data.title, data.icon)
    end
)

-- Handle APUS inference response
Handlers.add(
    "Infer-Response",
    Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        if msg.Code then
            print("Inference error: " .. msg.Code .. " - " .. (msg.Data or ""))
            return
        end
        
        local reference = msg["X-Reference"] or ""
        
        -- Parse response based on reference
        local data = msg.Data
        if type(data) == "string" then
            local success, parsed = pcall(json.decode, data)
            if success and parsed.result then
                data = parsed.result
            end
        end
        
        if string.find(reference, "self%-analysis") then
            local result = type(data) == "table" and data.result or data
            ArtAgent.analysis = ScholarUtils.parseAnalysis(result)
            print("Analysis complete (LLM)")
            ArtAgent.extractMetrics()
            
        elseif string.find(reference, "metrics") then
            local result = type(data) == "table" and data.result or data
            ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(result)
            print("Metrics extracted (LLM)")
            
            local text_excerpt = string.sub(ArtAgent.text, 1, 500)
            ArtAgent.fingerprint = ScholarUtils.createFingerprint(
                ArtAgent.analysis,
                ArtAgent.metrics,
                text_excerpt
            )
            
            ArtAgent.registerWithCoordinator()
            
        elseif string.find(reference, "compare") then
            local result = type(data) == "table" and data.result or data
            local relationship = RelationshipAnalyzer.parseRelationship(result)
            
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

-- Registration result
Handlers.add(
    "Registration-Result",
    Handlers.utils.hasMatchingTag("Action", "Registration-Result"),
    function(msg)
        local result = json.decode(msg.Data)
        
        if result.status == "duplicate" then
            print("Duplicate detected, original: " .. result.original_agent)
            ArtAgent.completeDiscovery()
        else
            print("Registered successfully")
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

-- Get status
Handlers.add(
    "Get-Status",
    Handlers.utils.hasMatchingTag("Action", "Get-Status"),
    function(msg)
        Send({
            Target = msg.From,
            Action = "Status",
            Data = json.encode({
                initialized = ArtAgent.initialized,
                apus_ready = ArtAgent.apus_ready,
                text_ready = ArtAgent.text_ready,
                title = ArtAgent.title,
                analysis = ArtAgent.analysis,
                metrics = ArtAgent.metrics,
                discovery_status = ArtAgent.discovery and
                    ArtAgent.discovery:getSummary() or "not started"
            })
        })
    end
)

-- Initialize on spawn
print("Art Agent Process: " .. ao.id)
installAPM()

return ArtAgent