-- session_manager.lua
local SessionManager = {}

-- Create new session manager (for Gemma context)
function SessionManager.new()
    local self = {
        active_sessions = {},
        session_count = 0,
        max_sessions = 5  -- Conservative limit for art agent
    }
    
    setmetatable(self, {__index = SessionManager})
    return self
end

-- Get or create session for analysis type
function SessionManager:getSession(session_type, agent_id)
    local session_key = session_type .. "-" .. agent_id
    
    if not self.active_sessions[session_key] then
        -- Check if at limit
        if self.session_count >= self.max_sessions then
            self:pruneOldestSession()
        end
        
        self.active_sessions[session_key] = {
            id = "session-" .. session_key .. "-" .. os.time(),
            created = os.time(),
            last_used = os.time(),
            type = session_type
        }
        self.session_count = self.session_count + 1
    end
    
    self.active_sessions[session_key].last_used = os.time()
    return self.active_sessions[session_key].id
end

-- Remove oldest session
function SessionManager:pruneOldestSession()
    local oldest_key = nil
    local oldest_time = os.time()
    
    for key, session in pairs(self.active_sessions) do
        if session.last_used < oldest_time then
            oldest_time = session.last_used
            oldest_key = key
        end
    end
    
    if oldest_key then
        self.active_sessions[oldest_key] = nil
        self.session_count = self.session_count - 1
    end
end

-- Clear all sessions
function SessionManager:clear()
    self.active_sessions = {}
    self.session_count = 0
end

-- Get session info
function SessionManager:getInfo()
    return {
        active_count = self.session_count,
        max_sessions = self.max_sessions,
        sessions = self.active_sessions
    }
end

return SessionManager