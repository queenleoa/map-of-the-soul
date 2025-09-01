-- utils/discovery_manager.lua
local MetricsConfig = require("config.metrics_config")

local DiscoveryManager = {}

function DiscoveryManager.new(agent_id)
    local self = {
        agent_id = agent_id,
        examined_agents = {},
        relationships = {},
        credits_used = 0,
        llm_apus_calls = 0,
        discovery_complete = false
    }
    
    setmetatable(self, {__index = DiscoveryManager})
    return self
end

function DiscoveryManager:shouldStop()
    -- Check sibling condition
    local sibling_count = 0
    for _, rel in ipairs(self.relationships) do
        if rel.type == "sibling" then
            sibling_count = sibling_count + 1
        end
    end
    
    if sibling_count > 0 and #self.relationships >= MetricsConfig.DISCOVERY.max_relationships_with_sibling then
        return true
    end
    
    if #self.relationships >= MetricsConfig.DISCOVERY.max_relationships_without_sibling then
        return true
    end
    
    local examined_count = 0
    for _ in pairs(self.examined_agents) do
        examined_count = examined_count + 1
    end
    
    if examined_count >= MetricsConfig.DISCOVERY.max_agents_to_examine then
        return true
    end
    
    return false
end

function DiscoveryManager:markExamined(agent_id)
    self.examined_agents[agent_id] = true
end

function DiscoveryManager:isExamined(agent_id)
    return self.examined_agents[agent_id] == true
end

function DiscoveryManager:addRelationship(rel)
    if rel.type ~= "none" then
        table.insert(self.relationships, rel)
    end
end

function DiscoveryManager:useCredit()
    self.credits_used = self.credits_used + 1
end

function DiscoveryManager:useLLMApus()
    self.llm_apus_calls = self.llm_apus_calls + 1
end

function DiscoveryManager:getNextCandidates()
    local candidates = {}
    
    -- Prioritize siblings and cousins for network exploration
    for _, rel in ipairs(self.relationships) do
        if (rel.type == "sibling" or rel.type == "cousin") and 
           not self:isExamined(rel.peer_id) then
            table.insert(candidates, rel.peer_id)
        end
    end
    
    return candidates
end

function DiscoveryManager:getSummary()
    local relationship_counts = {}
    for _, rel in ipairs(self.relationships) do
        relationship_counts[rel.type] = (relationship_counts[rel.type] or 0) + 1
    end
    
    local examined_count = 0
    for _ in pairs(self.examined_agents) do
        examined_count = examined_count + 1
    end
    
    return {
        total_examined = examined_count,
        total_relationships = #self.relationships,
        relationship_breakdown = relationship_counts,
        credits_used = self.credits_used,
        llm_apus_calls = self.llm_apus_calls
    }
end

return DiscoveryManager