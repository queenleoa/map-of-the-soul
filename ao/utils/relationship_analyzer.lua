-- utils/relationship_analyzer.lua
local json = require("json")
local MetricsConfig = require("config.metrics_config")

local RelationshipAnalyzer = {}

-- Check exact duplicate
function RelationshipAnalyzer.checkDuplicate(hash1, hash2)
    return hash1 == hash2
end

-- Calculate similarity score based on metrics
function RelationshipAnalyzer.calculateSimilarity(metrics1, metrics2)
    local score = 0
    local weights = {
        themes = 30,
        emotions = 20,
        form = 15,
        narrative_voice = 10,
        imagery_domains = 15,
        rhetorical_devices = 10
    }
    
    -- Compare themes
    local theme_overlap = 0
    for _, t1 in ipairs(metrics1.themes or {}) do
        for _, t2 in ipairs(metrics2.themes or {}) do
            if t1 == t2 then
                theme_overlap = theme_overlap + 1
            end
        end
    end
    score = score + (theme_overlap / math.max(#(metrics1.themes or {}), 1)) * weights.themes
    
    -- Compare emotions
    local emotion_overlap = 0
    for _, e1 in ipairs(metrics1.emotions or {}) do
        for _, e2 in ipairs(metrics2.emotions or {}) do
            if e1 == e2 then
                emotion_overlap = emotion_overlap + 1
            end
        end
    end
    score = score + (emotion_overlap / math.max(#(metrics1.emotions or {}), 1)) * weights.emotions
    
    -- Compare form
    if metrics1.form == metrics2.form then
        score = score + weights.form
    end
    
    -- Compare narrative voice
    if metrics1.narrative_voice == metrics2.narrative_voice then
        score = score + weights.narrative_voice
    end
    
    return score
end

-- Determine relationship type from score
function RelationshipAnalyzer.determineType(score)
    if score >= MetricsConfig.THRESHOLDS.version then
        return "version"
    elseif score >= MetricsConfig.THRESHOLDS.sibling then
        return "sibling"
    elseif score >= MetricsConfig.THRESHOLDS.cousin then
        return "cousin"
    elseif score >= MetricsConfig.THRESHOLDS.distant_cousin then
        return "distant_cousin"
    else
        return "none"
    end
end

-- Parse relationship from LLM response
function RelationshipAnalyzer.parseRelationship(response)
    -- Try to extract JSON
    local json_str = response:match("{.-}")
    if json_str then
        local success, result = pcall(json.decode, json_str)
        if success then
            return {
                type = string.lower(result.type or "none"),
                score = tonumber(result.score) or 0,
                justification = result.justification or ""
            }
        end
    end
    
    -- Fallback: keyword matching
    local relationship = {
        type = "none",
        score = 0,
        justification = ""
    }
    
    local response_lower = string.lower(response)
    if string.find(response_lower, "duplicate") then
        relationship.type = "duplicate"
        relationship.score = 100
    elseif string.find(response_lower, "version") then
        relationship.type = "version"
        relationship.score = 90
    elseif string.find(response_lower, "sibling") then
        relationship.type = "sibling"
        relationship.score = 75
    elseif string.find(response_lower, "cousin") and not string.find(response_lower, "distant") then
        relationship.type = "cousin"
        relationship.score = 60
    elseif string.find(response_lower, "distant") then
        relationship.type = "distant_cousin"
        relationship.score = 40
    end
    
    return relationship
end

return RelationshipAnalyzer