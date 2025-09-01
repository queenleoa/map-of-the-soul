-- utils/gemma_interface.lua
local json = require("json")
local ProcessConfig = require("config.process_config")

local GemmaInterface = {}

-- Process IDs
GemmaInterface.LLM_APUS = ProcessConfig.PROCESSES.llm_apus
GemmaInterface.MAX_CONTEXT = 32000

-- Build request for llm_apus process (after free credits exhausted)
function GemmaInterface.buildLLMApusRequest(prompt, reference)
    -- Simple truncation if needed
    if string.len(prompt) > 100000 then
        prompt = string.sub(prompt, 1, 100000) .. "\n... [truncated]"
    end
    
    return {
        Target = GemmaInterface.LLM_APUS,
        Action = "Infer",
        ["X-Prompt"] = prompt,
        ["X-Reference"] = reference or ("llm-" .. os.time()),
        ["X-Options"] = json.encode({
            temperature = 0.7,
            max_tokens = 2048,
            top_p = 0.9
        })
    }
end

-- Parse response from llm_apus
function GemmaInterface.parseLLMApusResponse(msg)
    if not msg or not msg.Data then
        return nil
    end
    
    -- Try to parse JSON response
    local success, data = pcall(json.decode, msg.Data)
    if success and data.result then
        return data.result
    end
    
    -- Return raw data if not JSON
    return msg.Data
end

return GemmaInterface