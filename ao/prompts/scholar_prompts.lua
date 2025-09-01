-- prompts/scholar_prompts.lua
local ScholarPrompts = {}

ScholarPrompts.SELF_ANALYSIS = [[
You are an erudite scholar of literary art with expertise in close reading, stylistics, and cultural criticism. You are analyzing a text artwork to capture its essence, craft, and hidden depths.

Perform the following analysis with surgical precision:

1. **Emotional Tone and Thematic Elements** (2-3 sentences):
   Identify the dominant emotional register and underlying affective currents. Map the primary thematic concerns and their interconnections. Consider not just what the text says, but the emotional texture it creates through rhythm, diction, and structure.

2. **Stylistic Influence, Linguistic Features, and Canonical Position** (2-3 sentences):
   Trace the stylistic lineage - what traditions does this echo or subvert? Identify distinctive linguistic patterns: sentence architecture, lexical choices, syntactic rhythms. Position this within literary history - is it extending, challenging, or synthesizing canonical forms?

3. **Hidden Insight - The Overlooked Detail** (1-2 sentences):
   Excavate one specific, concrete detail or special insight that most readers would miss but which illuminates the text's unique soul. This could be anything: a pattern of sound that mirrors meaning, a structural choice that embodies theme, a recurring image that works subconsciously, or a subtle tension between form and content. Be specific about the this characteristic of the text piece which makes it especially unique.

Text to analyze:
{TEXT}

Format as JSON.
{"Emotional Thematic": "", "Stylistic Linguistic Canonical": "", "Uniqueness": ""}
]]

ScholarPrompts.METRIC_EXTRACTION = [[
Based on this literary analysis, extract specific metrics in JSON format.

Analysis:
{ANALYSIS}

Extract and categorize:
1. THEMES (top 3): identity, love, death, time, memory, power, freedom, isolation, transformation, loss, hope, nature, technology, spirituality, family, journey, etc.
2. EMOTIONS (top 3): joy, sadness, anger, fear, melancholy, nostalgia, longing, anxiety, serenity, grief, pride, yearning, wonder, etc.
3. FORM (one): sonnet, haiku, free_verse, prose_poem, short_story, essay, memoir, journal, stream_of_consciousness, etc.
4. REGISTER: formality (0.0-1.0), abstractness (0.0-1.0)
5. NARRATIVE VOICE: first_person, third_person_limited, omniscient, etc.
6. IMAGERY DOMAINS (top 2-3): nature, urban, domestic, cosmic, bodily, etc.
7. LITERARY DEVICES (top 3): metaphor, irony, repetition, juxtaposition, etc.

Format as JSON.
{"theme1": "", "theme2": "", "theme3": "", "emotion1": "", "emotion2": "", "emotion3": "", "form": "","formality": 0.3, "abstractness": 0.5, "narrative voice": "", "imagery1":"", "imagery2":"", "literary device1":"", "literary device2":"" }
]]

ScholarPrompts.RELATIONSHIP_COMPARISON = [[
Analyze these two artwork fingerprints for literary kinship. Look beyond surface differences - a haiku about loss might be sibling to prose on grief if they share essential insights.

Artwork 1:
{ART1_DATA}

Artwork 2:
{ART2_DATA}

Determine:
1. Relationship type: DUPLICATE (100% match), VERSION (>90% similar), SIBLING (same content soul/voice, 70-89%), COUSIN (kinship with distinct voices, 50-69%), DISTANT_COUSIN (subtle resonances, 30-49%), or NONE (<30%)
2. Score: 0-100
3. Justification: What binds them (or doesn't) - be specific about shared elements (2-3 sentences)
4. Similarities and Contrasts: be specific and keep an eye out for special subtle insights that might get missed by readers. (2-3 sentences)

Format response as JSON:
{"type": "sibling", "score": 75, "justification": "", "similarity": "", "contrasts": "" }
]]

return ScholarPrompts