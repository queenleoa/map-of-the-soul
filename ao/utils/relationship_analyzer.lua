-- utils/relationship_analyzer.lua
local json = require("json")
local MetricsConfig = require("config.metrics_config")
local PromptBuilder = require("utils.prompt_builder")

local RelationshipAnalyzer = {}

-- Check for exact duplicate using text hash
function RelationshipAnalyzer.checkDuplicate(hash1, hash2)
    return hash1 == hash2
end

-- Calculate baseline similarity from metrics
function RelationshipAnalyzer.calculateMetricSimilarity(metrics1, metrics2)
    if not metrics1 or not metrics2 then
        return 0
    end
    
    local score = 0
    local weights = {
        themes = 30,
        emotions = 25,
        form = 20,
        narrative_voice = 10,
        imagery_domains = 10,
        literary_devices = 5
    }
    
    -- Compare themes
    if metrics1.themes and metrics2.themes then
        local theme_overlap = 0
        for _, t1 in ipairs(metrics1.themes) do
            for _, t2 in ipairs(metrics2.themes) do
                if t1 == t2 then
                    theme_overlap = theme_overlap + 1
                    break
                end
            end
        end
        if #metrics1.themes > 0 or #metrics2.themes > 0 then
            local max_themes = math.max(#metrics1.themes, #metrics2.themes, 1)
            score = score + (theme_overlap / max_themes) * weights.themes
        end
    end
    
    -- Compare emotions
    if metrics1.emotions and metrics2.emotions then
        local emotion_overlap = 0
        for _, e1 in ipairs(metrics1.emotions) do
            for _, e2 in ipairs(metrics2.emotions) do
                if e1 == e2 then
                    emotion_overlap = emotion_overlap + 1
                    break
                end
            end
        end
        if #metrics1.emotions > 0 or #metrics2.emotions > 0 then
            local max_emotions = math.max(#metrics1.emotions, #metrics2.emotions, 1)
            score = score + (emotion_overlap / max_emotions) * weights.emotions
        end
    end
    
    -- Compare form (exact match)
    if metrics1.form and metrics2.form and metrics1.form == metrics2.form then
        score = score + weights.form
    end
    
    -- Compare narrative voice
    if metrics1.narrative_voice and metrics2.narrative_voice and 
       metrics1.narrative_voice == metrics2.narrative_voice then
        score = score + weights.narrative_voice
    end
    
    -- Compare imagery domains
    if metrics1.imagery_domains and metrics2.imagery_domains then
        local imagery_overlap = 0
        for _, i1 in ipairs(metrics1.imagery_domains) do
            for _, i2 in ipairs(metrics2.imagery_domains) do
                if i1 == i2 then
                    imagery_overlap = imagery_overlap + 1
                    break
                end
            end
        end
        if #metrics1.imagery_domains > 0 or #metrics2.imagery_domains > 0 then
            local max_imagery = math.max(#metrics1.imagery_domains, #metrics2.imagery_domains, 1)
            score = score + (imagery_overlap / max_imagery) * weights.imagery_domains
        end
    end
    
    -- Compare literary devices
    if metrics1.literary_devices and metrics2.literary_devices then
        local device_overlap = 0
        for _, d1 in ipairs(metrics1.literary_devices) do
            for _, d2 in ipairs(metrics2.literary_devices) do
                if d1 == d2 then
                    device_overlap = device_overlap + 1
                    break
                end
            end
        end
        if #metrics1.literary_devices > 0 or #metrics2.literary_devices > 0 then
            local max_devices = math.max(#metrics1.literary_devices, #metrics2.literary_devices, 1)
            score = score + (device_overlap / max_devices) * weights.literary_devices
        end
    end
    
    return score
end

-- Parse single relationship from LLM response (pairwise comparison only)
function RelationshipAnalyzer.parseRelationship(response)
    -- Expected JSON format from RELATIONSHIP_COMPARISON:
    -- {"type": "sibling", "score": 75, "justification": "", "similarity": "", "contrasts": ""}
    
    local relationship = {
        type = "none",
        score = 0,
        justification = "",
        similarity = "",
        contrasts = ""
    }
    
    -- Try to extract JSON
    local json_str = response:match("{.-}")
    if json_str then
        local success, result = pcall(json.decode, json_str)
        if success then
            -- Parse type and normalize
            local rel_type = string.lower(result.type or "none")
            
            -- Map relationship types to MetricsConfig.THRESHOLDS
            if rel_type == "duplicate" then
                relationship.type = "duplicate"
                relationship.score = tonumber(result.score) or MetricsConfig.THRESHOLDS.duplicate
            elseif rel_type == "version" then
                relationship.type = "version"
                relationship.score = tonumber(result.score) or MetricsConfig.THRESHOLDS.version
            elseif rel_type == "sibling" then
                relationship.type = "sibling"
                relationship.score = tonumber(result.score) or MetricsConfig.THRESHOLDS.sibling
            elseif rel_type == "cousin" then
                relationship.type = "cousin"
                relationship.score = tonumber(result.score) or MetricsConfig.THRESHOLDS.cousin
            elseif rel_type == "distant_cousin" or string.find(rel_type, "distant") then
                relationship.type = "distant_cousin"
                relationship.score = tonumber(result.score) or MetricsConfig.THRESHOLDS.distant_cousin
            else
                relationship.type = "none"
                relationship.score = tonumber(result.score) or 0
            end
            
            -- Get other fields
            relationship.justification = result.justification or ""
            relationship.similarity = result.similarity or ""
            relationship.contrasts = result.contrasts or ""
            
            return relationship
        end
    end
    
    -- Fallback: keyword matching in response text
    local response_lower = string.lower(response)
    
    if string.find(response_lower, "duplicate") then
        relationship.type = "duplicate"
        relationship.score = MetricsConfig.THRESHOLDS.duplicate
    elseif string.find(response_lower, "version") then
        relationship.type = "version"
        relationship.score = MetricsConfig.THRESHOLDS.version
    elseif string.find(response_lower, "sibling") and not string.find(response_lower, "distant") then
        relationship.type = "sibling"
        relationship.score = MetricsConfig.THRESHOLDS.sibling
    elseif string.find(response_lower, "cousin") and not string.find(response_lower, "distant") then
        relationship.type = "cousin"
        relationship.score = MetricsConfig.THRESHOLDS.cousin
    elseif string.find(response_lower, "distant") then
        relationship.type = "distant_cousin"
        relationship.score = MetricsConfig.THRESHOLDS.distant_cousin
    end
    
    -- Try to extract justification from text
    relationship.justification = response:match("justification[^:]*:%s*([^\n]+)") or 
                                response:match("because%s+([^\n]+)") or ""
    relationship.similarity = response:match("similarity[^:]*:%s*([^\n]+)") or ""
    relationship.contrasts = response:match("contrasts[^:]*:%s*([^\n]+)") or ""
    
    return relationship
end

-- Create comparison prompt for pairwise comparison only
function RelationshipAnalyzer.createComparisonPrompt(agent1, agent2)
    -- Use PromptBuilder to create the comparison prompt
    return PromptBuilder.buildComparisonPrompt(agent1, agent2)
end

-- Determine if two agents should be compared based on metrics
function RelationshipAnalyzer.shouldCompare(metrics1, metrics2)
    -- Calculate baseline similarity
    local similarity = RelationshipAnalyzer.calculateMetricSimilarity(metrics1, metrics2)
    
    -- Only compare if there's at least minimal similarity
    -- Using distant_cousin threshold as minimum
    return similarity >= (MetricsConfig.THRESHOLDS.distant_cousin * 0.5)  -- 15% minimum
end

-- Determine relationship type from score using thresholds
function RelationshipAnalyzer.determineType(score)
    if score >= MetricsConfig.THRESHOLDS.duplicate then
        return "duplicate"
    elseif score >= MetricsConfig.THRESHOLDS.version then
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

return RelationshipAnalyzer