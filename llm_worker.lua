-- llm_worker.lua
-- Single funded scorer process. Receives ScorePair from agents and calls APUS (Gemma).
-- Falls back to a cheap local scorer when APUS is disabled.

local json = require('json')

-- Toggle at runtime via: Send({Target=<worker>, Action='Config', Tags={UseAPUS='true'}})
UseAPUS     = (UseAPUS == nil) and false or UseAPUS
APUS_ROUTER = APUS_ROUTER or 'Bf6JJR2tl2Wr38O2-H6VctqtduxHgKF-NzRB9HhTRzo'  -- default from docs

-- Track pending by reference -> { requester=PID, src=PID, dst=PID }
Pending = Pending or {}

local function build_prompt(a, b)
  return [[You are a strict JSON scoring function.
Compare Text A and Text B for three independent notions:
- semantic (themes/concepts)
- style (tone/voice/imagery/structure)
- emotion (valence/arousal/mood)
Return ONLY minified JSON with numeric fields in [0,1]:
{"semantic":0.0,"style":0.0,"emotion":0.0}
No explanations.
---
Text A:
]] .. a .. "\n---\nText B:\n" .. b .. "\n---\nJSON:"
end

-- Simple heuristic scorer for local fallback
local function local_fallback(a, b)
  local function tokenize_words(s)
    s = s:lower():gsub("[^%w%s]", " ")
    local t = {}
    for w in s:gmatch("%S+") do t[w] = true end
    return t
  end
  local function jaccard(t1, t2)
    local i, u = 0, 0
    local seen = {}
    for k in pairs(t1) do seen[k] = true end
    for k in pairs(t2) do seen[k] = true end
    for k in pairs(seen) do
      local a1 = t1[k] and 1 or 0
      local b1 = t2[k] and 1 or 0
      if a1 == 1 or b1 == 1 then u = u + 1 end
      if a1 == 1 and b1 == 1 then i = i + 1 end
    end
    return u == 0 and 0 or i / u
  end
  local function chargrams(s)
    s = s:lower():gsub("%s+", " ")
    local set = {}
    for i = 1, math.max(0, #s - 2) do set[s:sub(i, i + 2)] = true end
    return set
  end
  local jw = jaccard(tokenize_words(a), tokenize_words(b))
  local jc = jaccard(chargrams(a), chargrams(b))
  return { semantic = jw, style = jc, emotion = math.min(1.0, jw * 0.6 + jc * 0.4) }
end

-- Configure worker (enable APUS / change Router)
Handlers.add('Config', { Action = 'Config' }, function (msg)
  local tags = msg.Tags or {}
  if tags.UseAPUS == 'true'  then UseAPUS = true  end
  if tags.UseAPUS == 'false' then UseAPUS = false end
  if tags.Router and #tags.Router > 5 then APUS_ROUTER = tags.Router end
  msg.reply({ Action = 'OK', Data = (UseAPUS and 'APUS enabled' or 'APUS disabled') })
end)

-- Score a pair of texts
Handlers.add('ScorePair', { Action = 'ScorePair' }, function (msg)
  local payload = json.decode(msg.Data or '{}')
  local textA   = payload.textA or ''
  local textB   = payload.textB or ''
  local ref     = tostring(os.time()) .. '-' .. math.random(100000, 999999)

  if UseAPUS then
    ao.send({
      Target       = APUS_ROUTER,
      Action       = 'Infer',
      ["X-Prompt"] = build_prompt(textA, textB),
      ["X-Reference"] = ref,
      ["X-Options"] = json.encode({ temperature = 0.1, max_tokens = 150 })
    })
    Pending[ref] = { requester = msg.From, src = payload.src, dst = payload.dst }
  else
    -- LOCAL MODE: reply directly so .receive() prints in shell
    local scores = local_fallback(textA, textB)
    msg.reply({ Action = 'Score-Result', Data = json.encode({
      ref = ref, src = payload.src, dst = payload.dst, scores = scores
    }) })
  end
end)

-- Receive APUS result (from Router), parse, and forward to original requester
Handlers.add('AcceptResponse', { Action = 'Infer-Response' }, function (msg)
  local ref = msg["X-Reference"]
  if not ref or not Pending[ref] then return end

  local requester = Pending[ref].requester
  local src       = Pending[ref].src
  local dst       = Pending[ref].dst
  Pending[ref] = nil

  local raw = ''
  local ok, parsed = pcall(json.decode, msg.Data or '{}')
  if ok and parsed and parsed.result then raw = parsed.result else raw = msg.Data or '' end

  local ok2, scores = pcall(json.decode, raw)
  if not ok2 then
    local candidate = raw:match("%b{}") or '{}'
    ok2, scores = pcall(json.decode, candidate)
  end
  if not ok2 then
    scores = { semantic = 0, style = 0, emotion = 0 }
  end

  ao.send({
    Target = requester,
    Action = 'Score-Result',
    Data   = json.encode({ ref = ref, src = src, dst = dst, scores = scores })
  })
end)

-- Debug helper
Handlers.add('DumpState', { Action = 'DumpState' }, function(msg)
  local pendingCount = 0
  for _ in pairs(Pending) do pendingCount = pendingCount + 1 end
  msg.reply({ Action = 'State', Data = json.encode({
    UseAPUS = UseAPUS,
    APUS_ROUTER = APUS_ROUTER,
    pending = pendingCount
  }) })
end)
