-- utils/discovery_manager.lua
local MetricsConfig = require("config.metrics_config")

local DiscoveryManager = {}

function DiscoveryManager.new(agent_id)
    local self = {
        agent_id = agent_id,
        examined_agents = {},
        relationships = {},
        art_agent_credits = 0,
        llm_apus_calls = 0,
        discovery_complete = false,
        has_sibling = false
    }
    
    setmetatable(self, {__index = DiscoveryManager})
    return self
end

-- Check if discovery should stop based on MetricsConfig.DISCOVERY limits
function DiscoveryManager:shouldStop()
    -- Check for sibling relationships
    for _, rel in ipairs(self.relationships) do
        if rel.type == "sibling" then
            self.has_sibling = true
            break
        end
    end
    
    -- Check relationship limits from MetricsConfig
    if self.has_sibling and 
       #self.relationships >= MetricsConfig.DISCOVERY.max_relationships_with_sibling then
        return true
    end
    
    if not self.has_sibling and 
       #self.relationships >= MetricsConfig.DISCOVERY.max_relationships_without_sibling then
        return true
    end
    
    -- Check examined agents limit
    local examined_count = 0
    for _ in pairs(self.examined_agents) do
        examined_count = examined_count + 1
    end
    
    if examined_count >= MetricsConfig.DISCOVERY.max_agents_to_examine then
        return true
    end
    
    return false
end

-- Mark agent as examined
function DiscoveryManager:markExamined(agent_id)
    self.examined_agents[agent_id] = true
end

-- Check if agent has been examined
function DiscoveryManager:isExamined(agent_id)
    return self.examined_agents[agent_id] == true
end

-- Add discovered relationship
function DiscoveryManager:addRelationship(rel)
    if rel.type ~= "none" then
        table.insert(self.relationships, rel)
        if rel.type == "sibling" then
            self.has_sibling = true
        end
    end
end

-- Track art agent credit usage (called when using own credits)
function DiscoveryManager:useArtAgentCredit()
    self.art_agent_credits = self.art_agent_credits + 1
end

-- Track LLM APUS usage (called when using external LLM)
function DiscoveryManager:useLLMApus()
    self.llm_apus_calls = self.llm_apus_calls + 1
end

-- Determine if should switch to LLM APUS based on MetricsConfig.CREDITS
function DiscoveryManager:shouldUseLLMApus()
    -- Switch to LLM APUS after using threshold from config
    return self.art_agent_credits >= MetricsConfig.CREDITS.switch_to_llm_apus
end

-- Get next candidates based on relationships
function DiscoveryManager:getNextCandidates(relationships)
    local candidates = {}
    local added = {}
    
    -- Use relationships parameter or instance relationships
    local rels = relationships or self.relationships
    
    -- Prioritize based on relationship type
    -- First: siblings
    for _, rel in ipairs(rels) do
        if rel.type == "sibling" and 
           not self:isExamined(rel.peer_id) and 
           not added[rel.peer_id] then
            table.insert(candidates, rel.peer_id)
            added[rel.peer_id] = true
        end
    end
    
    -- Second: cousins
    for _, rel in ipairs(rels) do
        if rel.type == "cousin" and 
           not self:isExamined(rel.peer_id) and 
           not added[rel.peer_id] then
            table.insert(candidates, rel.peer_id)
            added[rel.peer_id] = true
        end
    end
    
    -- Third: distant cousins (up to network_share_limit)
    if #candidates < MetricsConfig.DISCOVERY.network_share_limit then
        for _, rel in ipairs(rels) do
            if rel.type == "distant_cousin" and 
               not self:isExamined(rel.peer_id) and 
               not added[rel.peer_id] then
                table.insert(candidates, rel.peer_id)
                added[rel.peer_id] = true
                if #candidates >= MetricsConfig.DISCOVERY.network_share_limit then
                    break
                end
            end
        end
    end
    
    return candidates
end

-- Get discovery summary
function DiscoveryManager:getSummary()
    local relationship_counts = {
        duplicate = 0,
        version = 0,
        sibling = 0,
        cousin = 0,
        distant_cousin = 0
    }
    
    -- Count relationships by type
    for _, rel in ipairs(self.relationships) do
        if relationship_counts[rel.type] then
            relationship_counts[rel.type] = relationship_counts[rel.type] + 1
        end
    end
    
    -- Count examined agents
    local examined_count = 0
    for _ in pairs(self.examined_agents) do
        examined_count = examined_count + 1
    end
    
    return {
        total_examined = examined_count,
        total_relationships = #self.relationships,
        relationship_breakdown = relationship_counts,
        art_agent_credits = self.art_agent_credits,
        llm_apus_calls = self.llm_apus_calls,
        has_sibling = self.has_sibling
    }
end

return DiscoveryManager