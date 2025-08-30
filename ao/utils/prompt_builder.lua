-- prompt_builder.lua
local json = require("json")
local PromptBuilder = {}

-- Self-analysis prompt
PromptBuilder.SELF_ANALYSIS_PROMPT = [[
You are an erudite scholar of literary art with expertise in close reading, stylistics, and cultural criticism. You are analyzing a text artwork to capture its essence, craft, and hidden depths.

Perform the following analysis with surgical precision:

1. **Emotional Tone and Thematic Elements** (2-3 sentences):
   Identify the dominant emotional register and underlying affective currents. Map the primary thematic concerns and their interconnections. Consider not just what the text says, but the emotional texture it creates through rhythm, diction, and structure.

2. **Stylistic Influence, Linguistic Features, and Canonical Position** (2-3 sentences):
   Trace the stylistic lineage - what traditions does this echo or subvert? Identify distinctive linguistic patterns: sentence architecture, lexical choices, syntactic rhythms. Position this within literary history - is it extending, challenging, or synthesizing canonical forms?

3. **Hidden Insight - The Overlooked Detail** (1-2 sentences):
   Excavate one specific, concrete detail that most readers would miss but which illuminates the text's unique soul. This could be: a pattern of sound that mirrors meaning, a structural choice that embodies theme, a recurring image that works subconsciously, or a subtle tension between form and content. Be specific - name the exact words, line breaks, or punctuation that creates this effect.

The text to analyze:
{TEXT}
]]

-- Metric extraction prompt
PromptBuilder.METRIC_EXTRACTION_PROMPT = [[
Based on this literary analysis, extract specific metrics.

Analysis:
{ANALYSIS}

Extract and categorize:
1. THEMES (top 3): identity, love, death, time, memory, power, freedom, isolation, transformation, loss, hope, nature, technology, spirituality, family, journey, etc.
2. EMOTIONS (top 3): joy, sadness, anger, fear, melancholy, nostalgia, longing, anxiety, serenity, grief, pride, yearning, wonder, etc.
3. FORM (one): sonnet, haiku, free_verse, prose_poem, short_story, essay, memoir, journal, stream_of_consciousness, etc.
4. REGISTER: formality (0.0-1.0), abstractness (0.0-1.0)
5. NARRATIVE VOICE: first_person, third_person_limited, omniscient, etc.
6. IMAGERY DOMAINS (top 2-3): nature, urban, domestic, cosmic, bodily, etc.
7. RHETORICAL DEVICES (top 3): metaphor, irony, repetition, juxtaposition, etc.
8. SYNTACTIC COMPLEXITY: simple, complex, compound_complex, fragmentary
9. LEXICAL DIVERSITY: low, medium, high, very_high
10. FIGURATIVE DENSITY: sparse, moderate, rich, saturated

Format as JSON.
]]

-- Build self-analysis prompt
function PromptBuilder.buildSelfAnalysisPrompt(text)
    return string.gsub(PromptBuilder.SELF_ANALYSIS_PROMPT, "{TEXT}", text)
end

-- Build metric extraction prompt
function PromptBuilder.buildMetricExtractionPrompt(analysis)
    return string.gsub(PromptBuilder.METRIC_EXTRACTION_PROMPT, "{ANALYSIS}", json.encode(analysis))
end

-- Build LLM_APUS process request
function PromptBuilder.buildLLMApusRequest(prompt, reference)
    return {
        Target = "A5TeWstBP1mD3FiZoU9JrbFUQ9Xg-hBgxHT7oeEVMr0", -- llm_apus process ID
        Action = "Infer",
        ["X-Prompt"] = prompt,
        ["X-Reference"] = reference or ("ref-" .. os.time())
    }
end

-- Build coordinator query
function PromptBuilder.buildCoordinatorQuery(action, data)
    return {
        Action = action,
        Data = json.encode(data)
    }
end

return PromptBuilder