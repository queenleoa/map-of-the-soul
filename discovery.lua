-- discovery.lua
-- Lightweight intro directory by SimHash prefix (2^P buckets). Not a coordinator.
-- Agents self-register and query peers here, then talk to each other directly.

local json = require('json')

DIR = DIR or { buckets = {}, last = os.time() }
PREFIX_BITS = PREFIX_BITS or 12  -- 12 -> 4096 buckets; change via Config if needed

local function patch()
  Send({
    device = 'patch@1.0',
    cache  = { discovery = { last = DIR.last, prefixBits = PREFIX_BITS } }
  })
end

Handlers.add('Config', { Action = 'Config' }, function(msg)
  local bits = tonumber((msg.Tags and msg.Tags.PrefixBits) or '')
  if bits and bits >= 4 and bits <= 16 then PREFIX_BITS = bits end
  patch()
  msg.reply({ Action = 'OK', Data = tostring(PREFIX_BITS) })
end)

Handlers.add('RegisterPrefix', { Action = 'RegisterPrefix' }, function(msg)
  local prefix = (msg.Tags and msg.Tags.Prefix) or msg.Prefix
  if not prefix or #prefix == 0 then return end

  DIR.buckets[prefix] = DIR.buckets[prefix] or {}
  DIR.buckets[prefix][msg.From] = true
  DIR.last = os.time()

  patch()
  msg.reply({ Action = 'Registered' })
end)

Handlers.add('QueryPrefix', { Action = 'QueryPrefix' }, function(msg)
  local prefix = (msg.Tags and msg.Tags.Prefix) or msg.Prefix
  local peers = {}

  if prefix and DIR.buckets[prefix] then
    for pid, _ in pairs(DIR.buckets[prefix]) do
      if pid ~= msg.From then peers[#peers + 1] = pid end
    end
  end

  msg.reply({
    Action = 'QueryResult',
    Data   = json.encode({ peers = peers, prefix = prefix })
  })
end)

-- Debug helper: dump bucket stats (counts per prefix)
Handlers.add('DumpState', { Action = 'DumpState' }, function(msg)
  local sizes = {}
  local bucketCount = 0
  for p, set in pairs(DIR.buckets) do
    bucketCount = bucketCount + 1
    local c = 0
    for _ in pairs(set) do c = c + 1 end
    sizes[p] = c
  end
  msg.reply({
    Action = 'State',
    Data   = json.encode({
      bucketCount = bucketCount,
      sizes      = sizes,
      last       = DIR.last,
      prefixBits = PREFIX_BITS
    })
  })
end)

-- Patch once on boot so FE/debug tools can read something immediately
if not __DiscoveryPatched then
  __DiscoveryPatched = true
  patch()
end
