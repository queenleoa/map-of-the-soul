-- config/process_config.lua
local ProcessConfig = {}

-- Essential process IDs
ProcessConfig.PROCESSES = {
    -- LLM APUS for relationship analysis (1000 credits)
    llm_apus = "A5TeWstBP1mD3FiZoU9JrbFUQ9Xg-hBgxHT7oeEVMr0",
    
    -- Coordinator (set during deployment)
    coordinator = "ZzJ0V-nD3E0XT2tBFXpPdNaifFVXpHbKwigx_xJNMZw"  -- Will be set when spawning agents
}

-- APUS AI settings
ProcessConfig.APUS = {
    temperature = 0.7,
    max_tokens = 2048,
    top_p = 0.9
}

return ProcessConfig