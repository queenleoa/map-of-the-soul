-- llm_worker.lua
-- Single funded scorer process. Receives ScorePair from agents and calls APUS (Gemma).
-- Can also run a local fallback if APUS is disabled (for Day 1 smoke tests).

local json = require('json')

-- Toggle at runtime: send Action=Config {UseAPUS=true/false}
UseAPUS = (UseAPUS == nil) and false or UseAPUS
APUS_ROUTER = APUS_ROUTER or 'Bf6JJR2tl2Wr38O2-H6VctqtduxHgKF-NzRB9HhTRzo'  -- default from docs

-- Track pending by reference -> { requester=PID, src=PID, dst=PID }
Pending = Pending or {}

local function build_prompt(a, b)
  return [[You are a strict JSON scoring function.
Compare Text A and Text B for three independent notions: semantic (themes/concepts), style (tone/voice/imagery/structure), and emotion (valence/arousal/mood).
Return only a minified JSON object with numeric fields in [0,1]:
{"semantic":0.0,"style":0.0,"emotion":0.0}
No explanations.
---
Text A:
]] .. a .. "\n---\nText B:\n" .. b .. "\n---\nJSON:"
end

local function local_fallback(a, b)
  -- Cheap bag-of-words Jaccard + char-3gram overlap to emulate three heads
  local function tokenize_words(s)
    s = s:lower():gsub("[^%w%s]", " ")
    local t = {}
    for w in s:gmatch("%S+") do t[w] = true end
    return t
  end
  local function jaccard(t1, t2)
    local i,u=0,0
    local seen={}
    for k,_ in pairs(t1) do seen[k]=true end
    for k,_ in pairs(t2) do seen[k]=true end
    for k,_ in pairs(seen) do
      local a = t1[k] and 1 or 0
      local b = t2[k] and 1 or 0
      if a==1 or b==1 then u=u+1 end
      if a==1 and b==1 then i=i+1 end
    end
    if u==0 then return 0 end
    return i/u
  end
  local function chargrams(s)
    s = s:lower():gsub("%s+", " ")
    local set = {}
    for i=1, #s-2 do set[s:sub(i,i+2)] = true end
    return set
  end
  local jw = jaccard(tokenize_words(a), tokenize_words(b))
  local jc = jaccard(chargrams(a), chargrams(b))
  -- Heuristic split across heads
  return { semantic = jw, style = jc, emotion = math.min(1.0, (jw*0.6 + jc*0.4)) }
end

Handlers.add('Config', { Action = 'Config' }, function (msg)
  if msg.Tags.UseAPUS == 'true' then UseAPUS = true elseif msg.Tags.UseAPUS == 'false' then UseAPUS = false end
  if msg.Tags.Router and #msg.Tags.Router > 5 then APUS_ROUTER = msg.Tags.Router end
  msg.reply({ Action = 'OK', Data = (UseAPUS and 'APUS enabled' or 'APUS disabled') })
end)

Handlers.add('ScorePair', { Action = 'ScorePair' }, function (msg)
  local payload = json.decode(msg.Data or '{}')
  local textA = payload.textA or ''
  local textB = payload.textB or ''
  local ref = tostring(os.time()) .. '-' .. math.random(100000,999999)
  if UseAPUS then
    ao.send({
      Target = APUS_ROUTER,
      Action = 'Infer',
      ["X-Prompt"]  = build_prompt(textA, textB),
      ["X-Reference"] = ref,
      ["X-Options"] = json.encode({ temperature = 0.1, max_tokens = 150 })
    })
    Pending[ref] = { requester = msg.From, src = payload.src, dst = payload.dst }
  else
    local scores = local_fallback(textA, textB)
    ao.send({ Target = msg.From, Action = 'Score-Result', Data = json.encode({ ref = ref, src = payload.src, dst = payload.dst, scores = scores }) })
  end
end)

Handlers.add('AcceptResponse', { Action = 'Infer-Response' }, function (msg)
  -- APUS Router replies here; Data.result carries model text
  local ref = msg["X-Reference"]
  if not ref or not Pending[ref] then return end
  local requester = Pending[ref].requester
  local src = Pending[ref].src
  local dst = Pending[ref].dst
  Pending[ref] = nil
  local raw = ''
  local ok, parsed = pcall(json.decode, msg.Data or '{}')
  if ok and parsed and parsed.result then raw = parsed.result else raw = msg.Data or '' end
  local ok2, scores = pcall(json.decode, raw)
  if not ok2 then
    -- If the model included text around JSON, try to extract minimal JSON
    local candidate = raw:match("%b{}") or '{}'
    ok2, scores = pcall(json.decode, candidate)
  end
  if not ok2 then
    scores = { semantic = 0, style = 0, emotion = 0 }
  end
  ao.send({ Target = requester, Action = 'Score-Result', Data = json.encode({ ref = ref, src = src, dst = dst, scores = scores }) })
end)