-- deploy.lua
local ao = require("ao")

-- Deploy coordinator
function deployCoordinator()
    local coordinatorId = ao.spawn({
        ["Process-Type"] = "Coordinator",
        ["App-Name"] = "ArtAgentCoordinator",
        ["App-Version"] = "1.0.0"
    })
    
    -- Load coordinator code
    ao.send({
        Target = coordinatorId,
        Action = "Eval",
        Data = coordinatorCode -- Load from coordinator.lua
    })
    
    print("Coordinator deployed: " .. coordinatorId)
    return coordinatorId
end

-- Register an artwork
function registerArtwork(coordinatorId, artworkId, contentHash, contentType)
    ao.send({
        Target = coordinatorId,
        Action = "RegisterArtwork",
        ArtworkId = artworkId,
        ContentHash = contentHash,
        ContentType = contentType
    })
end

-- Main deployment
local coordinator = deployCoordinator()

-- Example: Register some artworks
registerArtwork(coordinator, "art-001", "hash123abc", "text")
registerArtwork(coordinator, "art-002", "hash456def", "image")