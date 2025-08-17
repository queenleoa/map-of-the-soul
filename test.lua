-- test.lua

-- Test duplicate detection
function testDuplicateDetection()
    local coordinator = "coordinator-process-id"
    
    -- Register original artwork
    ao.send({
        Target = coordinator,
        Action = "RegisterArtwork",
        ArtworkId = "original-001",
        ContentHash = "abcd1234",
        ContentType = "text"
    })
    
    -- Wait for agent creation
    ao.delay(2000)
    
    -- Register duplicate artwork
    ao.send({
        Target = coordinator,
        Action = "RegisterArtwork",
        ArtworkId = "duplicate-001",
        ContentHash = "abcd1234", -- Same hash
        ContentType = "text"
    })
    
    -- Query for duplicates
    ao.delay(5000) -- Wait for agents to discover each other
    
    ao.send({
        Target = coordinator,
        Action = "QueryContent",
        ContentHash = "abcd1234"
    })
end

-- Test peer discovery
function testPeerDiscovery()
    -- Register multiple artworks
    for i = 1, 5 do
        ao.send({
            Target = coordinator,
            Action = "RegisterArtwork",
            ArtworkId = "art-" .. i,
            ContentHash = "hash-" .. i,
            ContentType = "text"
        })
    end
    
    -- Wait and check peer connections
    ao.delay(10000)
    
    -- Query agent list
    ao.send({
        Target = coordinator,
        Action = "ListAgents"
    })
end