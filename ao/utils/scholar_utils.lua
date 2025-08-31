-- scholar_utils.lua
local json = require("json")
local crypto = require(".crypto")

local ScholarUtils = {}

-- Generate a hash for text comparison
function ScholarUtils.hashText(text)
    return crypto.digest.sha256(text).hex()
end

-- Create a fingerprint from analysis results
function ScholarUtils.createFingerprint(analysis, metrics, text_excerpt)
    return {
        emotional_tone = analysis.emotional_tone,
        thematic_elements = analysis.thematic_elements,
        stylistic_features = analysis.stylistic_features,
        hidden_insight = analysis.hidden_insight,
        metrics = metrics,
        text_excerpt = text_excerpt or string.sub(analysis.original_text or "", 1, 500),
        timestamp = os.time()
    }
end

-- Format batch comparison request for LLM
function ScholarUtils.formatBatchComparison(agents, maxPerBatch)
    maxPerBatch = maxPerBatch or 5
    local batches = {}
    local currentBatch = {}
    
    for i = 1, #agents do
        table.insert(currentBatch, agents[i])
        if #currentBatch >= maxPerBatch then
            table.insert(batches, currentBatch)
            currentBatch = {}
        end
    end
    
    if #currentBatch > 0 then
        table.insert(batches, currentBatch)
    end
    
    return batches
end

-- Parse LLM response to extract metrics
function ScholarUtils.parseMetricsFromResponse(llmResponse)
    -- Try to extract JSON from response
    local json_start = string.find(llmResponse, "{")
    local json_end = string.find(llmResponse, "}", json_start or 1)
    
    if json_start and json_end then
        local json_str = string.sub(llmResponse, json_start, json_end)
        local success, metrics = pcall(json.decode, json_str)
        if success then
            return metrics
        end
    end
    
    -- Fallback: parse text manually
    return ScholarUtils.extractMetricsManually(llmResponse)
end

-- Manual extraction fallback
function ScholarUtils.extractMetricsManually(text)
    local metrics = {
        themes = {},
        emotions = {},
        form = "unknown",
        register = {formal = 0.5, abstract = 0.5},
        narrative_voice = "unknown",
        temporal_structure = "linear",
        imagery_domains = {},
        rhetorical_devices = {},
        syntactic_complexity = "mixed",
        lexical_diversity = "medium",
        figurative_density = "moderate"
    }
    
    -- Basic pattern matching for common terms
    -- This is a fallback - ideally Gemma returns proper JSON
    
    return metrics
end

return ScholarUtils