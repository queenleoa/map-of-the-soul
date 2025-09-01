-- utils/prompt_builder.lua
local json = require("json")
local ScholarPrompts = require("prompts.scholar_prompts")

local PromptBuilder = {}

-- Build self-analysis prompt from text
function PromptBuilder.buildSelfAnalysisPrompt(text)
    -- Truncate text if too long to fit in context window
    local max_chars = 50000  -- roughly 12k tokens
    if string.len(text) > max_chars then
        text = string.sub(text, 1, max_chars) .. "\n... [text truncated for analysis]"
    end
    
    -- Replace {TEXT} placeholder in SELF_ANALYSIS prompt
    return string.gsub(ScholarPrompts.SELF_ANALYSIS, "{TEXT}", text)
end

-- Build metric extraction prompt from BOTH analysis and text
function PromptBuilder.buildMetricExtractionPrompt(analysis, text)
    -- Format analysis for the {ANALYSIS} placeholder
    local analysis_text = string.format([[
Emotional Tone and Thematic Elements: %s
Stylistic Influence, Linguistic Features, and Canonical Position: %s
Hidden Insight - The Overlooked Detail: %s]], 
    analysis.emotional_tone or "",
    analysis.stylistic_features or "",
    analysis.hidden_insight or "")
    
    -- Truncate text if too long
    local max_text_chars = 30000  -- Leave room for analysis
    if string.len(text) > max_text_chars then
        text = string.sub(text, 1, max_text_chars) .. "\n... [text truncated]"
    end
    
    -- Replace both placeholders in METRIC_EXTRACTION prompt
    local prompt = ScholarPrompts.METRIC_EXTRACTION
    prompt = string.gsub(prompt, "{ANALYSIS}", analysis_text)
    prompt = string.gsub(prompt, "{TEXT}", text)
    
    return prompt
end

-- Build comparison prompt for two artworks (pairwise only)
function PromptBuilder.buildComparisonPrompt(agent1, agent2)
    local art1_data = PromptBuilder.formatArtworkData(agent1)
    local art2_data = PromptBuilder.formatArtworkData(agent2)
    
    -- Replace placeholders in RELATIONSHIP_COMPARISON prompt
    local prompt = ScholarPrompts.RELATIONSHIP_COMPARISON
    prompt = string.gsub(prompt, "{ART1_DATA}", art1_data)
    prompt = string.gsub(prompt, "{ART2_DATA}", art2_data)
    
    return prompt
end

-- Format artwork data for comparison (consistent field naming)
function PromptBuilder.formatArtworkData(agent_data)
    -- Extract data from agent structure
    local analysis = agent_data.analysis or {}
    local metrics = agent_data.metrics or {}
    local fingerprint = agent_data.fingerprint or {}
    
    -- Get themes (prioritize metrics, then fingerprint)
    local themes = metrics.themes or fingerprint.themes or {}
    local themes_str = table.concat(themes, ", ")
    
    -- Get emotions (prioritize metrics, then fingerprint)
    local emotions = metrics.emotions or fingerprint.emotions or {}
    local emotions_str = table.concat(emotions, ", ")
    
    -- Get form
    local form = metrics.form or fingerprint.form or "unknown"
    
    -- Get narrative voice
    local narrative_voice = metrics.narrative_voice or fingerprint.narrative_voice or "unknown"
    
    -- Get imagery domains
    local imagery_domains = metrics.imagery_domains or fingerprint.imagery_domains or {}
    local imagery_str = table.concat(imagery_domains, ", ")
    
    -- Get literary devices
    local literary_devices = metrics.literary_devices or fingerprint.literary_devices or {}
    local devices_str = table.concat(literary_devices, ", ")
    
    -- Get analysis components (consistent naming)
    local emotional_tone = analysis.emotional_tone or fingerprint.emotional_tone or ""
    local thematic_elements = analysis.thematic_elements or fingerprint.thematic_elements or ""
    local stylistic_features = analysis.stylistic_features or fingerprint.stylistic_features or ""
    local hidden_insight = analysis.hidden_insight or fingerprint.hidden_insight or ""
    
    -- Get text excerpt
    local text_excerpt = ""
    if agent_data.text then
        text_excerpt = string.sub(agent_data.text, 1, 500)
    elseif fingerprint.text_excerpt then
        text_excerpt = fingerprint.text_excerpt
    end
    
    -- Format according to what RELATIONSHIP_COMPARISON expects
    return string.format([[
Title/ID: %s
Emotional Tone: %s
Thematic Elements: %s
Stylistic Features: %s
Hidden Insight/Uniqueness: %s
Themes: %s
Emotions: %s
Form: %s
Narrative Voice: %s
Imagery Domains: %s
Literary Devices: %s
Text Excerpt: %s]], 
    agent_data.title or agent_data.agent_id or "Unknown",
    emotional_tone,
    thematic_elements,
    stylistic_features,
    hidden_insight,
    themes_str,
    emotions_str,
    form,
    narrative_voice,
    imagery_str,
    devices_str,
    text_excerpt)
end

return PromptBuilder