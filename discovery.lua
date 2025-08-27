-- discovery.lua
-- Lightweight intro directory by SimHash prefix (2^P buckets). Not a coordinator.
-- Agents self-register and query peers here, then talk to each other directly.

local json = require('json')

DIR = DIR or { buckets = {}, last = os.time() }
PREFIX_BITS = PREFIX_BITS or 12  -- 12 -> 4096 buckets; change via Config if needed

local function patch()
  Send({ device = 'patch@1.0', cache = { discovery = { last = DIR.last } } })
end

Handlers.add('Config', { Action = 'Config' }, function(msg)
  local bits = tonumber(msg.Tags.PrefixBits or '')
  if bits and bits >= 4 and bits <= 16 then PREFIX_BITS = bits end
  msg.reply({ Action = 'OK' })
  patch()
end)

Handlers.add('RegisterPrefix', { Action = 'RegisterPrefix' }, function(msg)
  local prefix = msg.Tags.Prefix
  if not prefix then return end
  DIR.buckets[prefix] = DIR.buckets[prefix] or {}
  DIR.buckets[prefix][msg.From] = true
  DIR.last = os.time()
  patch()
  msg.reply({ Action = 'Registered' })
end)

Handlers.add('QueryPrefix', { Action = 'QueryPrefix' }, function(msg)
  local prefix = msg.Tags.Prefix
  local peers = {}
  if prefix and DIR.buckets[prefix] then
    for pid, _ in pairs(DIR.buckets[prefix]) do
      if pid ~= msg.From then table.insert(peers, pid) end
    end
  end
  msg.reply({ Action = 'QueryResult', Data = json.encode({ peers = peers, prefix = prefix }) })
end)