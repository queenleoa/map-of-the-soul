-- utils/scholar_utils.lua
local json = require("json")
local crypto = require(".crypto")
local MetricsConfig = require("config.metrics_config")


local ScholarUtils = {}

-- Generate hash for text
function ScholarUtils.hashText(text)
    local str = text
    return crypto.digest.sha3_256(str).asHex()
end

-- Parse self-analysis from LLM response
function ScholarUtils.parseAnalysis(response)
    -- Expected JSON format from SELF_ANALYSIS prompt:
    -- {"Emotional Thematic": "", "Stylistic Linguistic Canonical": "", "Uniqueness": ""}
    
    local analysis = {
        emotional_thematic = "",
        stylistic_features = "",
        hidden_insight = ""
    }
    
    -- Try to extract JSON
    local json_str = response:match("{.-}")
    if json_str then
        local success, result = pcall(json.decode, json_str)
        if success then
            -- Map from prompt's JSON keys to internal field names
            analysis.emotional_thematic = result["Emotional Thematic"] or ""
            analysis.stylistic_features = result["Stylistic Linguistic Canonical"] or ""
            analysis.hidden_insight = result["Uniqueness"] or ""
            return analysis
        end
    end
    
    -- Fallback: parse from text if JSON fails
    analysis.emotional_thematic = response:match("Emotional Tone and Thematic Elements[^:]*:%s*([^\n]+)") or
                     response:match("Emotional Thematic[^:]*:%s*([^\n]+)") or ""
    
    analysis.stylistic_features = response:match("Stylistic Linguistic Canonical[^:]*:%s*([^\n]+)") or
                                  response:match("Stylistic.-Features[^:]*:%s*([^\n]+)") or ""
    
    analysis.hidden_insight = response:match("Uniqueness[^:]*:%s*([^\n]+)") or
                             response:match("Hidden Insight[^:]*:%s*([^\n]+)") or ""
    
    return analysis
end

-- Parse metrics from LLM response
function ScholarUtils.parseMetricsFromResponse(response)
    -- Expected JSON format from METRIC_EXTRACTION prompt:
    -- {"theme1": "", "theme2": "", "theme3": "", "emotion1": "", "emotion2": "", "emotion3": "", 
    --  "form": "", "formality": 0.3, "abstractness": 0.5, "narrative voice": "", 
    --  "imagery1": "", "imagery2": "", "literary device1": "", "literary device2": ""}
    
    local metrics = {
        themes = {},
        emotions = {},
        form = "unknown",
        register = {formality = 0.5, abstractness = 0.5},
        narrative_voice = "unknown",
        imagery_domains = {},
        literary_devices = {}
    }
    
    -- Try to extract JSON
    local json_str = response:match("{.-}")
    if json_str then
        local success, result = pcall(json.decode, json_str)
        if success then
            -- Extract themes (theme1, theme2, theme3)
            for i = 1, 3 do
                local theme = result["theme" .. i]
                if theme and theme ~= "" then
                    -- Validate against MetricsConfig.CATEGORIES.themes
                    theme = string.lower(theme)
                    for _, valid_theme in ipairs(MetricsConfig.CATEGORIES.themes) do
                        if theme == valid_theme or string.find(theme, valid_theme) then
                            table.insert(metrics.themes, valid_theme)
                            break
                        end
                    end
                end
            end
            
            -- Extract emotions (emotion1, emotion2, emotion3)
            for i = 1, 3 do
                local emotion = result["emotion" .. i]
                if emotion and emotion ~= "" then
                    -- Validate against MetricsConfig.CATEGORIES.emotions
                    emotion = string.lower(emotion)
                    for _, valid_emotion in ipairs(MetricsConfig.CATEGORIES.emotions) do
                        if emotion == valid_emotion or string.find(emotion, valid_emotion) then
                            table.insert(metrics.emotions, valid_emotion)
                            break
                        end
                    end
                end
            end
            
            -- Extract form and validate
            if result.form and result.form ~= "" then
                local form = string.lower(result.form)
                -- Check all form subcategories
                for category, forms in pairs(MetricsConfig.CATEGORIES.forms) do
                    if type(forms) == "table" then
                        for _, valid_form in ipairs(forms) do
                            if form == valid_form or string.find(form, string.gsub(valid_form, "_", " ")) then
                                metrics.form = valid_form
                                break
                            end
                        end
                    end
                    if metrics.form ~= "unknown" then break end
                end
            end
            
            -- Extract register (formality and abstractness)
            metrics.register.formality = tonumber(result.formality) or 0.5
            metrics.register.abstractness = tonumber(result.abstractness) or 0.5
            
            -- Extract narrative voice
            local voice = result["narrative voice"] or ""
            if voice ~= "" then
                voice = string.lower(string.gsub(voice, " ", "_"))
                for _, valid_voice in ipairs(MetricsConfig.CATEGORIES.narrative_voice) do
                    if voice == valid_voice or string.find(voice, valid_voice) then
                        metrics.narrative_voice = valid_voice
                        break
                    end
                end
            end
            
            -- Extract imagery domains (imagery1, imagery2)
            for i = 1, 2 do
                local imagery = result["imagery" .. i]
                if imagery and imagery ~= "" then
                    imagery = string.lower(imagery)
                    for _, valid_imagery in ipairs(MetricsConfig.CATEGORIES.imagery_domains) do
                        if imagery == valid_imagery or string.find(imagery, valid_imagery) then
                            table.insert(metrics.imagery_domains, valid_imagery)
                            break
                        end
                    end
                end
            end
            
            -- Extract literary devices (literary device1, literary device2)
            for i = 1, 2 do
                local device = result["literary device" .. i]
                if device and device ~= "" then
                    device = string.lower(device)
                    for _, valid_device in ipairs(MetricsConfig.CATEGORIES.literary_devices) do
                        if device == valid_device or string.find(device, valid_device) then
                            table.insert(metrics.literary_devices, valid_device)
                            break
                        end
                    end
                end
            end
            
            return metrics
        end
    end
    
    -- Fallback: extract from text if JSON parsing fails
    return ScholarUtils.extractMetricsFromText(response)
end

-- Fallback text extraction for metrics (basic keyword matching)
function ScholarUtils.extractMetricsFromText(text)
    local metrics = {
        themes = {},
        emotions = {},
        form = "unknown",
        register = {formality = 0.5, abstractness = 0.5},
        narrative_voice = "first_person",
        imagery_domains = {},
        literary_devices = {}
    }
    
    local text_lower = string.lower(text)
    
    -- Extract themes from MetricsConfig.CATEGORIES.themes
    for _, theme in ipairs(MetricsConfig.CATEGORIES.themes) do
        if string.find(text_lower, theme) then
            table.insert(metrics.themes, theme)
            if #metrics.themes >= 3 then break end
        end
    end
    
    -- Extract emotions from MetricsConfig.CATEGORIES.emotions
    for _, emotion in ipairs(MetricsConfig.CATEGORIES.emotions) do
        if string.find(text_lower, emotion) then
            table.insert(metrics.emotions, emotion)
            if #metrics.emotions >= 3 then break end
        end
    end
    
    -- Extract form from all subcategories
    for category, forms in pairs(MetricsConfig.CATEGORIES.forms) do
        if type(forms) == "table" then
            for _, form in ipairs(forms) do
                if string.find(text_lower, string.gsub(form, "_", " ")) then
                    metrics.form = form
                    break
                end
            end
        end
        if metrics.form ~= "unknown" then break end
    end
    
    -- Extract narrative voice
    for _, voice in ipairs(MetricsConfig.CATEGORIES.narrative_voice) do
        if string.find(text_lower, string.gsub(voice, "_", " ")) then
            metrics.narrative_voice = voice
            break
        end
    end
    
    -- Extract imagery domains
    for _, imagery in ipairs(MetricsConfig.CATEGORIES.imagery_domains) do
        if string.find(text_lower, imagery) then
            table.insert(metrics.imagery_domains, imagery)
            if #metrics.imagery_domains >= 2 then break end
        end
    end
    
    -- Extract literary devices
    for _, device in ipairs(MetricsConfig.CATEGORIES.literary_devices) do
        if string.find(text_lower, device) then
            table.insert(metrics.literary_devices, device)
            if #metrics.literary_devices >= 2 then break end
        end
    end
    
    return metrics
end

-- Create fingerprint for comparison
function ScholarUtils.createFingerprint(analysis, metrics, text_excerpt)
    return {
        emotional_thematic = analysis.emotional_thematic or "",
        stylistic_features = analysis.stylistic_features or "",
        hidden_insight = analysis.hidden_insight or "",
        themes = metrics.themes or {},
        emotions = metrics.emotions or {},
        form = metrics.form or "unknown",
        register = metrics.register or {formality = 0.5, abstractness = 0.5},
        narrative_voice = metrics.narrative_voice or "unknown",
        imagery_domains = metrics.imagery_domains or {},
        literary_devices = metrics.literary_devices or {},
        text_excerpt = text_excerpt or ""
    }
end

return ScholarUtils