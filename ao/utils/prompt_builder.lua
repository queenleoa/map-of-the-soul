-- utils/prompt_builder.lua
local json = require("json")
local ScholarPrompts = require("prompts.scholar_prompts")

local PromptBuilder = {}

function PromptBuilder.buildSelfAnalysisPrompt(text)
    return string.gsub(ScholarPrompts.SELF_ANALYSIS, "{TEXT}", text)
end

function PromptBuilder.buildMetricExtractionPrompt(analysis)
    return string.gsub(ScholarPrompts.METRIC_EXTRACTION, "{ANALYSIS}", json.encode(analysis))
end

function PromptBuilder.buildComparisonPrompt(art1_data, art2_data)
    local prompt = ScholarPrompts.RELATIONSHIP_COMPARISON
    prompt = string.gsub(prompt, "{ART1_DATA}", art1_data)
    prompt = string.gsub(prompt, "{ART2_DATA}", art2_data)
    return prompt
end

function PromptBuilder.formatArtworkData(agent_data)
    return string.format([[
Title: %s
Analysis: %s
Themes: %s
Emotions: %s
Form: %s
Uniqueness: %s
]], 
    agent_data.title or "Untitled",
    (agent_data.analysis.emotional_thematic or "") .. " " .. (agent_data.analysis.stylistic_linguistic_canonical or ""),
    table.concat(agent_data.metrics.themes or {}, ", "),
    table.concat(agent_data.metrics.emotions or {}, ", "),
    agent_data.metrics.form or "unknown",
    agent_data.analysis.Uniqueness or "")
end

return PromptBuilder