-- art_agent.lua (Simplified, hardened) with debug prints
local json = require("json")

-- Configuration requires
print("Loading config.metrics_config...")
local MetricsConfig = require("config.metrics_config")
print("MetricsConfig type:", type(MetricsConfig))

print("Loading config.process_config...")
local ProcessConfig = require("config.process_config")
print("ProcessConfig type:", type(ProcessConfig))

-- Utility requires
print("Loading utils.scholar_utils...")
local ScholarUtils = require("utils.scholar_utils")
print("ScholarUtils type:", type(ScholarUtils))
if type(ScholarUtils) == "table" then
    print("ScholarUtils.hashText type:", type(ScholarUtils.hashText))
    print("ScholarUtils.parseAnalysis type:", type(ScholarUtils.parseAnalysis))
end

print("Loading utils.prompt_builder...")
local PromptBuilder = require("utils.prompt_builder")
print("PromptBuilder type:", type(PromptBuilder))
if type(PromptBuilder) == "table" then
    print("PromptBuilder.buildSelfAnalysisPrompt type:", type(PromptBuilder.buildSelfAnalysisPrompt))
end

print("Loading utils.relationship_analyzer...")
local RelationshipAnalyzer = require("utils.relationship_analyzer")
print("RelationshipAnalyzer type:", type(RelationshipAnalyzer))

print("Loading utils.discovery_manager...")
local DiscoveryManager = require("utils.discovery_manager")
print("DiscoveryManager type:", type(DiscoveryManager))

-- Safe alias to avoid any accidental global 'string' shadowing elsewhere
local _string = string

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
ArtAgent.initialized = false

print("Checking ProcessConfig.PROCESSES...")
if ProcessConfig and ProcessConfig.PROCESSES then
    ArtAgent.coordinator_id = ProcessConfig.PROCESSES.coordinator
    ArtAgent.llm_apus = ProcessConfig.PROCESSES.llm_apus
else
    print("ERROR: ProcessConfig.PROCESSES is nil or invalid")
    ArtAgent.coordinator_id = nil
    ArtAgent.llm_apus = nil
end

print("ArtAgent expecting llm_apus at: " .. tostring(ArtAgent.llm_apus))
print("Coordinator at: " .. tostring(ArtAgent.coordinator_id))

-- Helper to send inference request to LLM APUS
function ArtAgent.sendInferRequest(prompt, reference, extra_tags)
  print("sendInferRequest called with prompt type:", type(prompt))
  local request = {
    Target         = ArtAgent.llm_apus,
    Action         = "Infer",
    ["X-Prompt"]   = tostring(prompt or ""),
    ["X-Reference"]= tostring(reference or ("ref-" .. os.time())),
    ["X-Options"]  = json.encode({
      temperature = 0.7,
      max_tokens  = 32000,
      top_p       = 0.9
    })
  }

  if extra_tags then
    for k, v in pairs(extra_tags) do
      request[k] = v
    end
  end

  Send(request)
end

-- Initialize agent with artwork text
function ArtAgent.initialize(text, title, icon)
  print("ArtAgent.initialize called with text type:", type(text))
  if ArtAgent.initialized then
    print("Already initialized")
    return
  end

  ArtAgent.text = text or ""
  ArtAgent.title = title or "Untitled"
  ArtAgent.icon = icon or "📝"
  
  print("Calling ScholarUtils.hashText...")
  if type(ScholarUtils.hashText) ~= "function" then
    print("ERROR: ScholarUtils.hashText is not a function, it's a " .. type(ScholarUtils.hashText))
    return
  end
  
  ArtAgent.text_hash = ScholarUtils.hashText(ArtAgent.text or "")
  
  print("Calling DiscoveryManager.new...")
  if type(DiscoveryManager.new) ~= "function" then
    print("ERROR: DiscoveryManager.new is not a function, it's a " .. type(DiscoveryManager.new))
    return
  end
  
  ArtAgent.discovery = DiscoveryManager.new(ao.id)
  ArtAgent.initialized = true

  print("Art Agent initialized: " .. ArtAgent.title)
  print("Text hash: " .. ArtAgent.text_hash)

  -- Start self-analysis
  ArtAgent.performSelfAnalysis()
end

-- Perform self-analysis using LLM APUS
function ArtAgent.performSelfAnalysis()
  print("Starting self-analysis...")
  print("ArtAgent.text type:", type(ArtAgent.text))
  
  if type(PromptBuilder.buildSelfAnalysisPrompt) ~= "function" then
    print("ERROR: PromptBuilder.buildSelfAnalysisPrompt is not a function, it's a " .. type(PromptBuilder.buildSelfAnalysisPrompt))
    return
  end
  
  local prompt = PromptBuilder.buildSelfAnalysisPrompt(ArtAgent.text or "")
  print("Prompt type:", type(prompt))
  print("Prompt length:", #prompt)
  
  local reference = "self-analysis-" .. os.time()
  ArtAgent.sendInferRequest(prompt, reference)
end

-- Extract metrics from analysis
function ArtAgent.extractMetrics()
  print("Extracting metrics...")
  local prompt = PromptBuilder.buildMetricExtractionPrompt(
    ArtAgent.analysis or {},
    ArtAgent.text or ""
  )
  local reference = "metrics-" .. os.time()
  ArtAgent.sendInferRequest(prompt, reference)
end

-- Register with coordinator
function ArtAgent.registerWithCoordinator()
  print("Registering with coordinator...")

  Send({
    Target = ArtAgent.coordinator_id,
    Action = "Register-Agent",
    Data = json.encode({
      agent_id   = ArtAgent.agent_id,
      title      = ArtAgent.title,
      icon       = ArtAgent.icon,
      text_hash  = ArtAgent.text_hash,
      analysis   = ArtAgent.analysis or {},
      metrics    = ArtAgent.metrics or {},
      fingerprint= ArtAgent.fingerprint or {},
      text       = ArtAgent.text or "" -- Include full text for comparisons
    })
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
      count = (MetricsConfig and MetricsConfig.DISCOVERY and MetricsConfig.DISCOVERY.initial_random_agents) or 5
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
      agent_id    = ArtAgent.agent_id,
      title       = ArtAgent.title,
      analysis    = ArtAgent.analysis,
      metrics     = ArtAgent.metrics,
      fingerprint = ArtAgent.fingerprint,
      text        = ArtAgent.text
    },
    other_agent
  )

  local reference = "compare-" .. tostring(other_agent.agent_id) .. "-" .. os.time()

  ArtAgent.sendInferRequest(prompt, reference, {
    ["X-Other-Agent"] = tostring(other_agent.agent_id)
  })
end

-- Register relationship
function ArtAgent.registerRelationship(relationship)
  if relationship.type == "none" then
    print("No relationship with " .. tostring(relationship.agent2))
    if ArtAgent.discovery and ArtAgent.discovery.markExamined then
      ArtAgent.discovery:markExamined(relationship.agent2)
    end

    if ArtAgent.discovery and ArtAgent.discovery.shouldStop and not ArtAgent.discovery:shouldStop() then
      ArtAgent.continueDiscovery()
    else
      ArtAgent.completeDiscovery()
    end
    return
  end

  print("Found " .. tostring(relationship.type) .. " with " .. tostring(relationship.agent2))

  -- Add to discovery
  if ArtAgent.discovery and ArtAgent.discovery.addRelationship then
    ArtAgent.discovery:addRelationship(relationship)
  end
  if ArtAgent.discovery and ArtAgent.discovery.markExamined then
    ArtAgent.discovery:markExamined(relationship.agent2)
  end

  -- Register with coordinator
  Send({
    Target = ArtAgent.coordinator_id,
    Action = "Register-Relationship",
    Data = json.encode(relationship)
  })

  -- Check if should continue
  if ArtAgent.discovery and ArtAgent.discovery.shouldStop and ArtAgent.discovery:shouldStop() then
    ArtAgent.completeDiscovery()
  else
    ArtAgent.continueDiscovery()
  end
end

-- Continue discovery
function ArtAgent.continueDiscovery()
  local candidates = {}
  if ArtAgent.discovery and ArtAgent.discovery.getNextCandidates then
    candidates = ArtAgent.discovery:getNextCandidates() or {}
  end

  if #candidates > 0 then
    Send({
      Target = ArtAgent.coordinator_id,
      Action = "Get-Agent-Info",
      Data = json.encode({ agent_ids = candidates })
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
  local summary = (ArtAgent.discovery and ArtAgent.discovery.getSummary and ArtAgent.discovery:getSummary()) or { total_relationships = 0 }

  print("Discovery complete!")
  print("Total relationships: " .. tostring(summary.total_relationships))

  Send({
    Target = ArtAgent.coordinator_id,
    Action = "Discovery-Complete",
    Data = json.encode({
      agent_id = ArtAgent.agent_id,
      summary = summary
    })
  })

  if ArtAgent.discovery then
    ArtAgent.discovery.discovery_complete = true
  end
end

-- HANDLERS

-- Initialize with text
Handlers.add(
  "Initialize",
  Handlers.utils.hasMatchingTag("Action", "Initialize"),
  function(msg)
    print("Initialize handler called")
    print("msg.Data type:", type(msg.Data))
    print("msg.Data:", tostring(msg.Data))
    
    local data = {}
    if msg.Data and #tostring(msg.Data) > 0 then
      local ok, parsed = pcall(json.decode, msg.Data)
      if ok and type(parsed) == "table" then 
        data = parsed
        print("Parsed data.text type:", type(data.text))
        print("Parsed data.title type:", type(data.title))
        print("Parsed data.icon type:", type(data.icon))
      else
        print("JSON decode failed:", tostring(parsed))
      end
    end
    
    print("Calling ArtAgent.initialize...")
    if type(ArtAgent.initialize) ~= "function" then
      print("ERROR: ArtAgent.initialize is not a function, it's a " .. type(ArtAgent.initialize))
      return
    end
    
    ArtAgent.initialize(data.text, data.title, data.icon)
  end
)

-- Handle inference response from LLM APUS
Handlers.add(
  "OnInferResponse",
  Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
  function(msg)
    if msg.Code then
      print("Inference error: " .. tostring(msg.Code) .. " - " .. tostring(msg.Data or ""))
      return
    end

    local reference = msg["X-Reference"] or ""
    local response_text = msg.Data
    if type(response_text) ~= "string" then
      response_text = json.encode(response_text or {})
    end

    print("Received inference response for: " .. reference)

    if _string.find(reference, "self%-analysis") then
      if type(ScholarUtils.parseAnalysis) ~= "function" then
        print("[BUG] ScholarUtils.parseAnalysis invalid, type=" .. type(ScholarUtils.parseAnalysis))
        return
      end
      ArtAgent.analysis = ScholarUtils.parseAnalysis(response_text) or {}
      print("Analysis complete")
      ArtAgent.extractMetrics()

    elseif _string.find(reference, "metrics") then
      if type(ScholarUtils.parseMetricsFromResponse) ~= "function" then
        print("[BUG] parseMetricsFromResponse invalid, type=" .. type(ScholarUtils.parseMetricsFromResponse))
        return
      end
      ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(response_text) or {}
      print("Metrics extracted")

      local text_excerpt = _string.sub(ArtAgent.text or "", 1, 500)
      if type(ScholarUtils.createFingerprint) ~= "function" then
        print("[BUG] createFingerprint invalid, type=" .. type(ScholarUtils.createFingerprint))
        return
      end
      ArtAgent.fingerprint = ScholarUtils.createFingerprint(
        ArtAgent.analysis or {},
        ArtAgent.metrics or {},
        text_excerpt
      ) or {}

      ArtAgent.registerWithCoordinator()

    elseif _string.find(reference, "compare") then
      if type(RelationshipAnalyzer.parseRelationship) ~= "function" then
        print("[BUG] parseRelationship invalid, type=" .. type(RelationshipAnalyzer.parseRelationship))
        return
      end
      local relationship = RelationshipAnalyzer.parseRelationship(response_text) or { type = "none" }
      local other_agent_id = msg["X-Other-Agent"]

      if other_agent_id then
        relationship.agent1 = ArtAgent.agent_id
        relationship.agent2 = other_agent_id
        relationship.peer_id = other_agent_id
        ArtAgent.registerRelationship(relationship)
      else
        print("Warning: No other agent ID in comparison response")
      end
    else
      print("Warning: Unknown reference pattern: " .. reference)
    end
  end
)

-- Registration result from coordinator
Handlers.add(
  "Registration-Result",
  Handlers.utils.hasMatchingTag("Action", "Registration-Result"),
  function(msg)
    local result = {}
    if msg.Data then
      local ok, parsed = pcall(json.decode, msg.Data)
      if ok and type(parsed) == "table" then result = parsed end
    end

    if result.status == "duplicate" then
      print("Duplicate detected, original: " .. tostring(result.original_agent))
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
    local agents = {}
    if msg.Data then
      local ok, parsed = pcall(json.decode, msg.Data)
      if ok and type(parsed) == "table" then agents = parsed end
    end

    print("Received " .. tostring(#agents) .. " agents to examine")

    for _, agent in ipairs(agents) do
      if ArtAgent.discovery and ArtAgent.discovery.isExamined and
         not ArtAgent.discovery:isExamined(agent.agent_id) and
         ArtAgent.discovery.shouldStop and not ArtAgent.discovery:shouldStop() then
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
    local agents = {}
    if msg.Data then
      local ok, parsed = pcall(json.decode, msg.Data)
      if ok and type(parsed) == "table" then agents = parsed end
    end

    for _, agent in ipairs(agents) do
      if ArtAgent.discovery and ArtAgent.discovery.isExamined and
         not ArtAgent.discovery:isExamined(agent.agent_id) and
         ArtAgent.discovery.shouldStop and not ArtAgent.discovery:shouldStop() then
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
        title = ArtAgent.title,
        analysis = ArtAgent.analysis,
        metrics = ArtAgent.metrics,
        discovery_status = ArtAgent.discovery and ArtAgent.discovery.getSummary and
          ArtAgent.discovery:getSummary() or "not started"
      })
    })
  end
)

print("Art Agent Process: " .. ao.id)
print("Ready for initialization. Send Initialize action with {text, title, icon}")

return ArtAgent