-- art_agent.lua
local json = require("json")

-- ================== State variables ==================
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
ArtAgent.modules_loaded = false

-- ================== Inline APM installer (as provided / working) ==================
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
  -- (keeping your original condition/logic)
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
  ArtAgent.apm_loaded = true
  print("✅ APM loaded, version: " .. version)

  -- Now install APUS (as in your working code)
  print("Installing APUS AI...")
  apm.install("@apus/ai")
end

Handlers.once(
  "APM.UpdateResponse",
  Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
  function(msg)
    HandleRun(InstallResponseHandler, msg)
  end
)

Send({
  Target = apm_id,
  Action = "APM.Update"
})
print("📦 Loading APM...")

-- ================== APUS detection (as in your working code) ==================
Handlers.add(
  "APUS.Check",
  function(msg)
    local data = msg.Data or ""
    if string.match(data, "Downloaded @apus/ai")
      or string.match(data, "apus/ai@")
      or string.match(data, "Successfully installed")
      or (string.match(data, "✅") and string.match(data, "apus")) then
      return true
    end
    return false
  end,
  function(msg)
    if not ArtAgent.apus_installed then
      print("APUS AI detected as installed")
      ArtAgent.apus_installed = true

      local success, result = pcall(function()
        ApusAI = require('@apus/ai')
        ApusAI_Debug = true
        return true
      end)

      if success then
        print("✅ APUS AI loaded successfully")
        ArtAgent.tryLoadModules()
      else
        print("⚠️ APUS require failed, will retry: " .. tostring(result))
      end
    end
  end
)

-- ================== Utility modules loader (from your working code) ==================
function ArtAgent.tryLoadModules()
  if ArtAgent.modules_loaded then return end

  local success = pcall(function()
    ScholarUtils         = require("utils.scholar_utils")
    RelationshipAnalyzer = require("utils.relationship_analyzer")
    DiscoveryManager     = require("utils.discovery_manager")
    PromptBuilder        = require("utils.prompt_builder")
    SessionManager       = require("utils.session_manager")
    ArweaveStorage       = require("utils.arweave_storage")
    MetricsConfig        = require("config.metrics_config")
  end)

  if success then
    ArtAgent.modules_loaded = true
    ArtAgent.session_manager = SessionManager.new()
    print("✅ All modules loaded")

    if ArtAgent.text ~= "" then
      ArtAgent.initialize()
    end
  else
    print("⚠️ Modules not yet available, will load when needed")
  end
end

-- ================== Initialize (original flow, with your fallbacks) ==================
function ArtAgent.initialize()
  if ArtAgent.initialized then return end
--   if not ArtAgent.apus_installed then
--     print("Waiting for APUS AI to install...")
--     return
--   end

  if not ApusAI then
    local success = pcall(function()
      ApusAI = require('@apus/ai')
      ApusAI_Debug = true
    end)
    if not success then
      print("APUS not ready yet, retrying...")
      return
    end
  end

  print("Initializing Art Agent...")

  if ScholarUtils and ScholarUtils.hashText then
    ArtAgent.text_hash = ScholarUtils.hashText(ArtAgent.text)
  else
    -- simple fallback hash
    local hash = 0
    for i = 1, #ArtAgent.text do
      hash = (hash * 31 + string.byte(ArtAgent.text, i)) % 2147483647
    end
    ArtAgent.text_hash = tostring(hash)
  end

  if DiscoveryManager then
    ArtAgent.discovery_manager = DiscoveryManager.new(ArtAgent.id)
  else
    -- minimal fallback discovery manager
    ArtAgent.discovery_manager = {
      examined_agents = {},
      relationships = {},
      art_agent_credits = 0,
      llm_apus_calls = 0,
      shouldStop = function() return #ArtAgent.relationships > 10 end,
      markExamined = function(self, id) self.examined_agents[id] = true end,
      isExamined = function(self, id) return self.examined_agents[id] end,
      useArtAgentCredit = function(self) self.art_agent_credits = self.art_agent_credits + 1 end,
      useLLMApus = function(self) self.llm_apus_calls = self.llm_apus_calls + 1 end,
      shouldUseLLMApus = function(self) return self.art_agent_credits >= 3 end,
      addRelationship = function(self, rel) table.insert(self.relationships, rel) end,
      getSummary = function(self)
        return {
          total_examined = 0,
          total_relationships = #self.relationships,
          art_agent_credits = self.art_agent_credits,
          llm_apus_calls = self.llm_apus_calls
        }
      end
    }
  end

  ArtAgent.analyzeSelf()
  ArtAgent.initialized = true
end

-- ================== Self-analysis (original) ==================
function ArtAgent.analyzeSelf()
  print("Starting self-analysis...")

  local prompt
  if PromptBuilder and PromptBuilder.buildSelfAnalysisPrompt then
    prompt = PromptBuilder.buildSelfAnalysisPrompt(ArtAgent.text)
  else
    prompt = string.format([[
Analyze this text and provide:
1. Emotional tone and thematic elements
2. Stylistic features
3. Hidden insight or unique characteristic

Text: %s

Format as JSON: {"Emotional Thematic": "", "Stylistic Linguistic Canonical": "", "Uniqueness": ""}
]], string.sub(ArtAgent.text, 1, 5000))
  end

  if ArtAgent.credits_remaining >= 2 then
    ApusAI.infer(prompt, {}, function(err, res)
      if err then
        print("Analysis error: " .. err.message)
        return
      end

      if ScholarUtils and ScholarUtils.parseAnalysis then
        ArtAgent.analysis = ScholarUtils.parseAnalysis(res.data)
      else
        ArtAgent.analysis = {
          emotional_tone       = res.data or "",
          thematic_elements    = "",
          stylistic_features   = "",
          hidden_insight       = ""
        }
      end

      ArtAgent.credits_remaining = ArtAgent.credits_remaining - 2
      ArtAgent.discovery_manager:useArtAgentCredit()
      ArtAgent.discovery_manager:useArtAgentCredit()

      print("Analysis complete, extracting metrics...")
      ArtAgent.extractMetrics()
    end)
  else
    print("Insufficient credits for self-analysis")
  end
end

-- ================== Extract metrics (original) ==================
function ArtAgent.extractMetrics()
  local metrics_prompt = PromptBuilder and PromptBuilder.buildMetricExtractionPrompt
      and PromptBuilder.buildMetricExtractionPrompt(ArtAgent.analysis, ArtAgent.text)
      or (("Extract concise metrics from this analysis and text:\n\nANALYSIS:\n%s\n\nTEXT:\n%s")
            :format(json.encode(ArtAgent.analysis), string.sub(ArtAgent.text,1,2000)))

  if ArtAgent.credits_remaining >= 1 then
    ApusAI.infer(metrics_prompt, {}, function(err, res)
      if err then
        print("Metrics extraction error: " .. err.message)
        return
      end

      if ScholarUtils and ScholarUtils.parseMetricsFromResponse then
        ArtAgent.metrics = ScholarUtils.parseMetricsFromResponse(res.data)
      else
        ArtAgent.metrics = { similarity_axes = {}, tags = {}, score_hint = 0 }
      end

      ArtAgent.credits_remaining = ArtAgent.credits_remaining - 1
      ArtAgent.discovery_manager:useArtAgentCredit()

      ArtAgent.fingerprint = (ScholarUtils and ScholarUtils.createFingerprint)
        and ScholarUtils.createFingerprint(ArtAgent.analysis, ArtAgent.metrics, string.sub(ArtAgent.text, 1, 500))
        or { hash = ArtAgent.text_hash, len = #ArtAgent.text }

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
      ArtAgent.registerWithCoordinator()
      ArtAgent.startDiscovery()
    end)
  else
    -- Fallback to external LLM
    ArtAgent.useExternalLLM(metrics_prompt, "metrics", function(response)
      ArtAgent.metrics = (ScholarUtils and ScholarUtils.parseMetricsFromResponse)
        and ScholarUtils.parseMetricsFromResponse(response)
        or { similarity_axes = {}, tags = {}, score_hint = 0 }

      ArtAgent.fingerprint = (ScholarUtils and ScholarUtils.createFingerprint)
        and ScholarUtils.createFingerprint(ArtAgent.analysis, ArtAgent.metrics, string.sub(ArtAgent.text, 1, 500))
        or { hash = ArtAgent.text_hash, len = #ArtAgent.text }

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

-- ================== Coordinator registration (original) ==================
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

-- ================== Discovery (original) ==================
function ArtAgent.startDiscovery()
  print("Starting peer discovery...")

  Send({
    Target = ArtAgent.coordinator_process,
    Action = "Get-Random-Agents",
    Data = json.encode({
      requester = ArtAgent.id,
      count = MetricsConfig.DISCOVERY.initial_random_agents
    })
  })
end

-- ================== External LLM (original) ==================
function ArtAgent.useExternalLLM(prompt, purpose, callback)
  local reference = "ext-" .. purpose .. "-" .. os.time()

  Send({
    Target = ArtAgent.llm_apus_process,
    Action = "Infer",
    ["X-Prompt"] = prompt,
    ["X-Reference"] = reference
  })

  ArtAgent["callback_" .. reference] = callback
  ArtAgent.discovery_manager:useLLMApus()
end

-- ================== Compare with peers (original) ==================
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

      if ArtAgent.discovery_manager:shouldUseLLMApus() or ArtAgent.credits_remaining < 1 then
        ArtAgent.useExternalLLM(comparison_prompt, "compare-" .. peer.agent_id, function(response)
          local result = RelationshipAnalyzer.parseRelationship(response)
          ArtAgent.processComparisonResult(result, peer.agent_id)
        end)
      else
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

-- ================== Process comparison result (original) ==================
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

    table.insert(ArtAgent.relationships, relationship)
    ArtAgent.discovery_manager:addRelationship(relationship)

    ArweaveStorage.storeRelationship(relationship)

    Send({
      Target = ArtAgent.coordinator_process,
      Action = "Register-Relationship",
      Data = json.encode(relationship)
    })

    if result.type == "sibling" or result.type == "cousin" then
      Send({
        Target = peer_id,
        Action = "Share-Network",
        Data = json.encode({ requester = ArtAgent.id })
      })
    end
  end

  if not ArtAgent.discovery_manager:shouldStop() then
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

-- ================== Finalize discovery (original) ==================
function ArtAgent.finalizeDiscovery()
  local summary = ArtAgent.discovery_manager:getSummary()

  print("Discovery complete!")
  print("Examined: " .. (summary.total_examined or 0) .. " agents")
  print("Relationships found: " .. (summary.total_relationships or #ArtAgent.relationships))
  print("Credits used: " .. (summary.art_agent_credits or 0))
  print("External LLM calls: " .. (summary.llm_apus_calls or 0))

  ArweaveStorage.storeDiscoveryReport(ArtAgent.id, summary)

  Send({
    Target = ArtAgent.coordinator_process,
    Action = "Discovery-Complete",
    Data = json.encode({
      agent_id = ArtAgent.id,
      summary = summary
    })
  })
end

-- ================== Handlers (original set) ==================
Handlers.add(
  "Set-Text",
  Handlers.utils.hasMatchingTag("Action", "Set-Text"),
  function(msg)
    ArtAgent.text = msg.Data
    ArtAgent.title = msg.Tags["Title"] or "Untitled"
    ArtAgent.icon = msg.Tags["Icon"] or "📝"
    ArtAgent.coordinator_process = msg.Tags["Coordinator"] or ""

    print("Text set: " .. ArtAgent.title)

    --if ArtAgent.apus_installed then
      ArtAgent.initialize()
    -- else
    --   print("Waiting for APUS AI to install...")
    --   Send({ Target = ao.id, Action = "Check-APUS" })
    -- end
  end
)

Handlers.add(
  "Random-Agents",
  Handlers.utils.hasMatchingTag("Action", "Random-Agents"),
  function(msg)
    local agents = json.decode(msg.Data)
    ArtAgent.compareWithPeers(agents)
  end
)

Handlers.add(
  "Agent-Info",
  Handlers.utils.hasMatchingTag("Action", "Agent-Info"),
  function(msg)
    local agents = json.decode(msg.Data)
    ArtAgent.compareWithPeers(agents)
  end
)

Handlers.add(
  "Infer-Response",
  Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
  function(msg)
    local reference = msg["X-Reference"]
    local callback = ArtAgent["callback_" .. reference]

    if callback then
      local data = msg.Data
      if msg.Code then
        print("LLM error: " .. msg.Code .. " - " .. data)
        return
      end

      local success, parsed = pcall(json.decode, data)
      if success and parsed and parsed.result then
        callback(parsed.result)
      else
        callback(data)
      end

      ArtAgent["callback_" .. reference] = nil
    end
  end
)

Handlers.add(
  "Share-Network",
  Handlers.utils.hasMatchingTag("Action", "Share-Network"),
  function(msg)
    local request = json.decode(msg.Data)

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

Handlers.add(
  "Network-Shared",
  Handlers.utils.hasMatchingTag("Action", "Network-Shared"),
  function(msg)
    local shared_relationships = json.decode(msg.Data)

    local new_peers = {}
    for _, rel in ipairs(shared_relationships) do
      if not ArtAgent.discovery_manager:isExamined(rel.peer_id) then
        table.insert(new_peers, rel.peer_id)
      end
    end

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
        apm_loaded = ArtAgent.apm_loaded,
        modules_loaded = ArtAgent.modules_loaded,
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
