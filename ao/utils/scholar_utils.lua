-- utils/scholar_utils.lua
local json = require("json")
local crypto = require(".crypto")
local MetricsConfig = require("config.metrics_config")

local ScholarUtils = {}

-- Generate hash for text
function ScholarUtils.hashText(text)
    return crypto.digest.sha256(text).hex()
end

-- Parse analysis from LLM response
function ScholarUtils.parseAnalysis(response)
    local analysis = {
        emotional_thematic = "",
        stylistic_linguistic_canonical = "",
        uniqueness = "",
        full_text = response
    }
    
    -- Try multiple parsing patterns
    local patterns = {
        emotional = {
            "Emotional Thematic[^:]*:%s*([^\n]+)",
            "1%.%s*%*%*[^%*]+%*%*%s*([^2]+)",
            "Emotional.-:%s*([^\n]+)"
        },
        stylistic = {
            "Stylistic[^:]*:%s*([^\n]+)",
            "2%.%s*%*%*[^%*]+%*%*%s*([^3]+)",
            "Linguistic.-:%s*([^\n]+)"
        },
        unique = {
            "Uniqueness[^:]*:%s*([^\n]+)",
            "3%.%s*%*%*[^%*]+%*%*%s*(.+)",
            "Overlooked.-:%s*([^\n]+)"
        }
    }
    
    for _, pattern in ipairs(patterns.emotional) do
        local match = response:match(pattern)
        if match then
            analysis.emotional_thematic = match:gsub("^%s+", ""):gsub("%s+$", "")
            break
        end
    end
    
    for _, pattern in ipairs(patterns.stylistic) do
        local match = response:match(pattern)
        if match then
            analysis.stylistic_linguistic_canonical = match:gsub("^%s+", ""):gsub("%s+$", "")
            break
        end
    end
    
    for _, pattern in ipairs(patterns.unique) do
        local match = response:match(pattern)
        if match then
            analysis.uniqueness = match:gsub("^%s+", ""):gsub("%s+$", "")
            break
        end
    end
    
    return analysis
end

-- Parse metrics from LLM response
function ScholarUtils.parseMetrics(response)
    -- Try to extract JSON
    local json_str = response:match("{.-}") or "{}"
    local success, metrics = pcall(json.decode, json_str)
    
    if success and metrics.themes then
        return ScholarUtils.validateMetrics(metrics)
    end
    
    -- Fallback: manual extraction
    return ScholarUtils.extractMetricsManually(response)
end

-- Validate and normalize metrics
function ScholarUtils.validateMetrics(metrics)
    local validated = {
        themes = {},
        emotions = {},
        form = "unknown",
        register = {formality = 0.5, abstractness = 0.5},
        narrative_voice = "unknown",
        imagery_domains = {},
        literary_devices = {}
    }
    
    -- Validate themes
    if metrics.themes then
        for i = 1, math.min(3, #metrics.themes) do
            local theme = string.lower(metrics.themes[i])
            for _, valid_theme in ipairs(MetricsConfig.CATEGORIES.themes) do
                if string.find(theme, valid_theme) then
                    table.insert(validated.themes, valid_theme)
                    break
                end
            end
        end
    end
    
    -- Validate emotions
    if metrics.emotions then
        for i = 1, math.min(3, #metrics.emotions) do
            local emotion = string.lower(metrics.emotions[i])
            for _, valid_emotion in ipairs(MetricsConfig.CATEGORIES.emotions) do
                if string.find(emotion, valid_emotion) then
                    table.insert(validated.emotions, valid_emotion)
                    break
                end
            end
        end
    end
    
    -- Set form
    if metrics.form then
        validated.form = string.lower(metrics.form)
    end
    
    -- Set register
    if metrics.register then
        validated.register.formality = tonumber(metrics.register.formality) or 0.5
        validated.register.abstractness = tonumber(metrics.register.abstractness) or 0.5
    end
    
    -- Copy other fields
    validated.narrative_voice = metrics.narrative_voice or "unknown"
    validated.imagery_domains = metrics.imagery_domains or {}
    validated.literary_devices = metrics.literary_devices or {}
    
    return validated
end

-- Manual extraction fallback
function ScholarUtils.extractMetricsManually(text)
    local metrics = {
        themes = {},
        emotions = {},
        form = "unknown",
        register = {formality = 0.5, abstractness = 0.5},
        narrative_voice = "first_person",
        imagery_domains = {},
        literary_devices = {}
    }
    
    -- Basic keyword matching for themes
    local text_lower = string.lower(text)
    for _, theme in ipairs({"identity", "love", "death", "time", "memory"}) do
        if string.find(text_lower, theme) then
            table.insert(metrics.themes, theme)
            if #metrics.themes >= 3 then break end
        end
    end
    
    -- Basic keyword matching for emotions
    for _, emotion in ipairs({"joy", "sadness", "fear", "longing", "wonder"}) do
        if string.find(text_lower, emotion) then
            table.insert(metrics.emotions, emotion)
            if #metrics.emotions >= 3 then break end
        end
    end
    
    return metrics
end

-- Create fingerprint for comparison
function ScholarUtils.createFingerprint(analysis, metrics)
    return {
        themes = table.concat(metrics.themes or {}, ","),
        emotions = table.concat(metrics.emotions or {}, ","),
        form = metrics.form,
        register = metrics.register,
        key_insight = string.sub(analysis.hidden_insight or "", 1, 200)
    }
end

return ScholarUtils