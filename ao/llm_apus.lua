-- llm_apus.lua handlers (add to existing llm_apus process)
local json = require("json")

-- Make sure APUS AI is loaded
ApusAI = ApusAI or require('@apus/ai')
ApusAI_Debug = true

-- Handler to receive inference requests and forward to APUS
Handlers.add(
  "ProcessInfer",
  Handlers.utils.hasMatchingTag("Action", "Infer"),
  function(msg)
    local prompt = msg["X-Prompt"] or msg.Data or ""
    local reference = msg["X-Reference"] or ("ref-" .. os.time())
    local options_str = msg["X-Options"] or "{}"

    -- Parse options
    local options = {}
    local ok, parsed = pcall(json.decode, options_str)
    if ok and type(parsed) == "table" then options = parsed end
    options.reference = reference

    print("Processing inference request from: " .. tostring(msg.From))
    print("Reference: " .. tostring(reference))

    -- Store requester info for callback
    local requester = msg.From
    local other_agent = msg["X-Other-Agent"]

    -- Call APUS AI
    ApusAI.infer(prompt, options, function(err, res)
      if err then
        local emsg = tostring(err and (err.message or err) or "Inference failed")
        print("APUS Error: " .. emsg)
        -- Send error response
        Send({
          Target = requester,
          Action = "Infer-Response",
          Code = "error",
          Data = emsg,
          ["X-Reference"] = reference
        })
        return
      end

      -- Normalize output to a STRING
      local out
      if type(res) == "string" then
        out = res
      elseif type(res) == "table" then
        out = res.data or res.output or res.text
        if type(out) ~= "string" and res.choices and res.choices[1] and res.choices[1].text then
          out = res.choices[1].text
        end
      end
      out = out or ""

      -- Send successful response
      local response_msg = {
        Target = requester,
        Action = "Infer-Response",
        Data = out,                -- ALWAYS send a string
        ["X-Reference"] = reference
      }

      -- Include session if available
      if type(res) == "table" and res.session then
        response_msg["X-Session"] = res.session
      end

      -- Include other agent ID if it was in the request
      if other_agent then
        response_msg["X-Other-Agent"] = other_agent
      end

      Send(response_msg)
      print("Sent response to: " .. tostring(requester))
    end)
  end
)

print("LLM APUS ready to process inference requests")
