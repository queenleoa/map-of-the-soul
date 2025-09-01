-- config/metrics_config.lua
local MetricsConfig = {}

-- Complete metric categories for Scholar mapping
MetricsConfig.CATEGORIES = {
    themes = {
        "identity", "love", "death", "time", "memory", "power", "freedom",
        "isolation", "community", "transformation", "loss", "hope", "despair",
        "nature", "technology", "spirituality", "sexuality", "violence", "peace",
        "justice", "oppression", "family", "friendship", "betrayal", "redemption",
        "creation", "destruction", "knowledge", "ignorance", "beauty", "ugliness",
        "truth", "deception", "journey", "home", "exile", "belonging",
        "innocence", "experience", "ambition", "failure", "success", "sacrifice",
        "duty", "rebellion", "tradition", "modernity", "alienation", "connection"
    },
    
    emotions = {
        "joy", "sadness", "anger", "fear", "surprise", "disgust", "trust", "anticipation",
        "melancholy", "nostalgia", "longing", "euphoria", "anxiety", "dread",
        "serenity", "rage", "terror", "ecstasy", "grief", "remorse", "shame",
        "pride", "envy", "compassion", "contempt", "awe", "confusion", "curiosity",
        "frustration", "satisfaction", "yearning", "resignation", "hope", "despair",
        "tenderness", "bitterness", "indifference", "passion", "apathy", "wonder"
    },
    
    forms = {
        poetry = {
            "sonnet", "haiku", "ghazal", "villanelle", "sestina", "pantoum",
            "free_verse", "prose_poem", "epic", "ballad", "ode", "elegy",
            "limerick", "tanka", "cinquain", "acrostic", "concrete_poetry"
        },
        prose = {
            "short_story", "flash_fiction", "novella", "novel_excerpt", "vignette",
            "stream_of_consciousness", "epistolary", "monologue"
        },
        nonfiction = {
            "essay", "memoir", "journal", "meditation", "manifesto", "critique",
            "reflection", "confession", "testimony", "letter", "aphorism"
        },
        experimental = {
            "hybrid", "experimental", "list", "erasure", "collage", "fragment"
        }
    },
    
    narrative_voice = {
        "first_person", "second_person", "third_person_limited", "third_person_omniscient",
        "collective_first", "shifting_perspective", "unreliable_narrator",
        "stream_of_consciousness", "epistolary_voice", "dramatic_monologue",
        "free_indirect_discourse", "objective"
    },
    
    temporal_structure = {
        "linear", "non_linear", "circular", "fragmented", "retrospective",
        "simultaneous", "reversed", "episodic", "continuous", "elliptical",
        "present_dominant", "past_dominant", "future_oriented", "timeless"
    },
    
    imagery_domains = {
        "nature", "urban", "domestic", "cosmic", "bodily", "mechanical",
        "aquatic", "aerial", "subterranean", "fire", "ice", "shadow",
        "light", "darkness", "botanical", "animal", "mineral", "synthetic",
        "religious", "mythological", "technological", "medical", "architectural"
    },
    
    literary_devices = {
        "metaphor", "simile", "personification", "allegory", "symbolism",
        "irony", "paradox", "oxymoron", "hyperbole", "litotes", "metonymy",
        "synecdoche", "anaphora", "epistrophe", "chiasmus", "asyndeton",
        "polysyndeton", "enjambment", "caesura", "alliteration", "assonance",
        "consonance", "onomatopoeia", "apostrophe", "zeugma", "antithesis",
        "juxtaposition", "repetition", "parallelism", "allusion", "ekphrasis"
    }
}

-- Relationship thresholds
MetricsConfig.THRESHOLDS = {
    duplicate = 100,
    version = 90,
    sibling = 70,
    cousin = 50,
    distant_cousin = 30
}

-- Credit management
MetricsConfig.CREDITS = {
    art_agent_free = 5,
    art_agent_analysis = 2,
    art_agent_metrics = 1,
    switch_to_llm_apus = 3
}

-- Discovery limits
MetricsConfig.DISCOVERY = {
    max_relationships_with_sibling = 10,
    max_relationships_without_sibling = 13,
    max_agents_to_examine = 25,
    initial_random_agents = 10,
    network_share_limit = 5
}

return MetricsConfig