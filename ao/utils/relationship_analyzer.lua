-- relationship_analyzer.lua
local json = require("json")

local RelationshipAnalyzer = {}

-- Relationship type definitions
RelationshipAnalyzer.TYPES = {
    DUPLICATE = "duplicate",
    VERSION = "version",
    SIBLING = "sibling",
    COUSIN = "cousin",
    DISTANT_COUSIN = "distant_cousin",
    NONE = "none"
}

-- Check for exact duplicate
function RelationshipAnalyzer.checkDuplicate(hash1, hash2)
    return hash1 == hash2
end

-- Create comparison prompt for batch processing
function RelationshipAnalyzer.createBatchComparisonPrompt(agent_pairs)
    local comparisons = {}
    
    for i, pair in ipairs(agent_pairs) do
        table.insert(comparisons, string.format([[
PAIR %d:
Artwork 1 - %s:
Analysis: %s | %s
Hidden Insight: %s
Themes: %s | Form: %s

Artwork 2 - %s:
Analysis: %s | %s
Hidden Insight: %s
Themes: %s | Form: %s
]], 
        i,
        pair.agent1.id or "unknown",
        pair.agent1.analysis.emotional_tone or "",
        pair.agent1.analysis.stylistic_features or "",
        pair.agent1.analysis.hidden_insight or "",
        table.concat(pair.agent1.metrics.themes or {}, ", "),
        pair.agent1.metrics.form or "",
        pair.agent2.id or "unknown",
        pair.agent2.analysis.emotional_tone or "",
        pair.agent2.analysis.stylistic_features or "",
        pair.agent2.analysis.hidden_insight or "",
        table.concat(pair.agent2.metrics.themes or {}, ", "),
        pair.agent2.metrics.form or ""
        ))
    end
    
    local prompt = [[
Analyze these artwork pairs for literary kinship. Look beyond surface differences - a haiku about loss might be sibling to prose on grief if they share essential insights.

]] .. table.concat(comparisons, "\n\n") .. [[

For each pair, determine:
- Relationship: VERSION (>90% similar), SIBLING (same soul/voice), COUSIN (kinship with distinct voices), DISTANT_COUSIN (subtle resonances), or NONE
- Score: 0-100
- Justification: What binds them (or doesn't)

Format as JSON array:
[{"pair": 1, "type": "sibling", "score": 75, "justification": "..."}, ...]
]]
    
    return prompt
end

-- Parse batch relationships from LLM response
function RelationshipAnalyzer.parseBatchRelationships(llmResponse)
    local success, results = pcall(json.decode, llmResponse)
    
    if not success then
        -- Try to extract JSON array from response
        local json_start = string.find(llmResponse, "%[")
        local json_end = string.find(llmResponse, "%]", json_start or 1)
        
        if json_start and json_end then
            local json_str = string.sub(llmResponse, json_start, json_end)
            success, results = pcall(json.decode, json_str)
        end
    end
    
    if success and type(results) == "table" then
        local relationships = {}
        for _, result in ipairs(results) do
            table.insert(relationships, {
                pair_index = result.pair or 0,
                type = result.type or RelationshipAnalyzer.TYPES.NONE,
                score = tonumber(result.score) or 0,
                justification = result.justification or "No justification provided"
            })
        end
        return relationships
    end
    
    -- Return empty array on parse failure
    return {}
end

-- Check if relationship meets threshold
function RelationshipAnalyzer.meetsThreshold(rel_type, score)
    local thresholds = {
        version = 90,
        sibling = 70,
        cousin = 50,
        distant_cousin = 30
    }
    
    local threshold = thresholds[rel_type] or 0
    return score >= threshold
end

return RelationshipAnalyzer