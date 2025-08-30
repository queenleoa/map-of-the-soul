-- discovery_manager.lua
local DiscoveryManager = {}

-- Create new discovery manager instance
function DiscoveryManager.new(agent_id)
    local self = {
        agent_id = agent_id,
        examined_agents = {},
        found_relationships = {},
        total_examined = 0,
        art_agent_credits_used = 0,
        llm_apus_calls = 0
    }
    
    setmetatable(self, {__index = DiscoveryManager})
    return self
end

-- Check if we should stop discovery
function DiscoveryManager:shouldStop()
    local sibling_count = 0
    for _, rel in ipairs(self.found_relationships) do
        if rel.type == "sibling" then
            sibling_count = sibling_count + 1
        end
    end
    
    -- Stop at 10 relationships if at least 1 sibling found
    if sibling_count > 0 and #self.found_relationships >= 10 then
        return true
    end
    
    -- Stop at 13 relationships if no siblings found
    if sibling_count == 0 and #self.found_relationships >= 13 then
        return true
    end
    
    -- Stop if examined 30 agents
    if self.total_examined >= 30 then
        return true
    end
    
    return false
end

-- Add discovered relationship
function DiscoveryManager:addRelationship(rel)
    if rel.type ~= "none" and rel.type ~= nil then
        table.insert(self.found_relationships, {
            peer_id = rel.peer_id,
            type = rel.type,
            score = rel.score,
            justification = rel.justification,
            discovered_at = os.time()
        })
    end
end

-- Mark agent as examined
function DiscoveryManager:markExamined(agent_id)
    self.examined_agents[agent_id] = true
    self.total_examined = self.total_examined + 1
end

-- Check if agent already examined
function DiscoveryManager:isExamined(agent_id)
    return self.examined_agents[agent_id] == true
end

-- Get agents to explore next (network expansion)
function DiscoveryManager:getNextCandidates(current_relatives)
    local candidates = {}
    
    for _, relative in ipairs(current_relatives) do
        if (relative.type == "sibling" or relative.type == "cousin") 
           and not self:isExamined(relative.peer_id) then
            table.insert(candidates, relative.peer_id)
        end
    end
    
    return candidates
end

-- Determine if should use llm_apus process
function DiscoveryManager:shouldUseLLMApus()
    -- Use llm_apus if art agent has used 3+ credits
    return self.art_agent_credits_used >= 3
end

-- Track credit usage
function DiscoveryManager:useArtAgentCredit()
    self.art_agent_credits_used = self.art_agent_credits_used + 1
    return self.art_agent_credits_used
end

-- Track llm_apus usage
function DiscoveryManager:useLLMApus()
    self.llm_apus_calls = self.llm_apus_calls + 1
    return self.llm_apus_calls
end

-- Get discovery summary
function DiscoveryManager:getSummary()
    local relationship_counts = {}
    for _, rel in ipairs(self.found_relationships) do
        relationship_counts[rel.type] = (relationship_counts[rel.type] or 0) + 1
    end
    
    return {
        total_examined = self.total_examined,
        total_relationships = #self.found_relationships,
        relationship_breakdown = relationship_counts,
        art_agent_credits = self.art_agent_credits_used,
        llm_apus_calls = self.llm_apus_calls
    }
end

return DiscoveryManager