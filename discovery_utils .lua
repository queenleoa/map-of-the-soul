-- discovery_utils.lua
local json = require("json")

-- Function to query Arweave index for agents
function queryArweaveAgents(contentType, callback)
    local graphql_query = [[
        query {
            transactions(
                tags: [
                    { name: "Process-Type", values: ["ArtAgent"] }
                    { name: "Content-Type", values: ["]] .. contentType .. [["] }
                ]
                first: 100
            ) {
                edges {
                    node {
                        id
                        tags {
                            name
                            value
                        }
                    }
                }
            }
        }
    ]]
    
    ao.send({
        Target = "Arweave-GraphQL", -- Hypothetical GraphQL gateway
        Action = "Query",
        Query = graphql_query,
        Callback = ao.id,
        CallbackAction = callback
    })
end

-- Function to introduce agents based on content similarity
function introduceCompatibleAgents(agent1, agent2)
    -- Send introduction message to both agents
    ao.send({
        Target = agent1,
        Action = "PeerIntroduction",
        PeerId = agent2,
        Reason = "ContentSimilarity"
    })
    
    ao.send({
        Target = agent2,
        Action = "PeerIntroduction",
        PeerId = agent1,
        Reason = "ContentSimilarity"
    })
end

-- Handler for peer introductions
Handlers.add(
    "PeerIntroduction",
    Handlers.utils.hasMatchingTag("Action", "PeerIntroduction"),
    function(msg)
        local peerId = msg.Tags.PeerId
        local reason = msg.Tags.Reason
        
        -- Add to peer list and initiate handshake
        PeerAgents[peerId] = {
            introducedBy = msg.From,
            reason = reason,
            timestamp = msg.Timestamp
        }
        
        -- Request fingerprint for comparison
        ao.send({
            Target = peerId,
            Action = "RequestFingerprint",
            RequesterId = ao.id,
            RequesterArtwork = ArtworkId
        })
    end
)