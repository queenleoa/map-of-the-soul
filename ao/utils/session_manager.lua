-- utils/session_manager.lua
-- Simplified session tracking for APUS AI context

local SessionManager = {}

function SessionManager.new()
    return {
        current_session = nil,
        session_type = nil
    }
end

-- Just track the current session ID from APUS
function SessionManager:setSession(session_id, session_type)
    self.current_session = session_id
    self.session_type = session_type
end

function SessionManager:getSession()
    return self.current_session
end

function SessionManager:clear()
    self.current_session = nil
    self.session_type = nil
end

return SessionManager