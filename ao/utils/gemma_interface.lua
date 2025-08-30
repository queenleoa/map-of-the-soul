-- gemma_interface.lua
local json = require("json")
local GemmaInterface = {}

-- Constants for Gemma configuration
GemmaInterface.MAX_TOKENS = 32000
GemmaInterface.DEFAULT_TEMPERATURE = 0.7
GemmaInterface.DEFAULT_MAX_RESPONSE = 2048

-- Build options for Gemma inference
function GemmaInterface.buildOptions(custom_options)
    local options = {
        temperature = GemmaInterface.DEFAULT_TEMPERATURE,
        max_tokens = GemmaInterface.DEFAULT_MAX_RESPONSE,
        top_p = 0.9
    }
    
    -- Merge custom options
    if custom_options then
        for k, v in pairs(custom_options) do
            options[k] = v
        end
    end
    
    return json.encode(options)
end

-- Create inference request for art agent's own credits
function GemmaInterface.createInferRequest(prompt, session_id, reference)
    return {
        prompt = prompt,
        options = {
            session = session_id,
            temperature = 0.7,
            max_tokens = 2048
        },
        reference = reference or ("infer-" .. os.time())
    }
end

-- Format request for llm_apus process (when out of credits)
function GemmaInterface.createLLMApusRequest(prompt, reference)
    return {
        Target = "A5TeWstBP1mD3FiZoU9JrbFUQ9Xg-hBgxHT7oeEVMr0",
        Action = "Infer",
        ["X-Prompt"] = prompt,
        ["X-Reference"] = reference or ("apus-" .. os.time()),
        ["X-Options"] = GemmaInterface.buildOptions()
    }
end

-- Check if response is within token limits
function GemmaInterface.checkTokenLimit(text)
    -- Rough estimate: 1 token ≈ 4 characters
    local estimated_tokens = string.len(text) / 4
    return estimated_tokens < GemmaInterface.MAX_TOKENS
end

-- Truncate text if too long for context window
function GemmaInterface.truncateForContext(text, max_chars)
    max_chars = max_chars or 100000  -- ~25k tokens
    if string.len(text) > max_chars then
        return string.sub(text, 1, max_chars) .. "... [truncated]"
    end
    return text
end

-- Parse Gemma response
function GemmaInterface.parseResponse(response)
    if type(response) == "string" then
        -- Try to extract structured data if present
        local success, data = pcall(json.decode, response)
        if success then
            return data
        end
        return { text = response }
    end
    return response
end

return GemmaInterface