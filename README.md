Map of the Soul - README
========================

Autonomous Art Agents Creating Self-Organizing Literary Networks on AO
----------------------------------------------------------------------

### 🎨 Overview

Map of the Soul is a revolutionary multi-agent system that transforms how we understand relationships between creative works. When text artwork is uploaded to Arweave, it spawns an autonomous AI agent that analyzes itself, discovers its literary family through peer-to-peer communication, and contributes to an ever-evolving map of creative connections. **The project demonstrates a step towards the big-vision of creating a new internet with intelligent and autonomously self-organising data.** 

Unlike traditional content analysis that relies on centralized categorization, Map of the Soul allows artworks to self-organize into organic networks of meaning, creating what we could call a "creative democracy" where each piece actively participates in defining its place in the cultural landscape. 

### 🌟 Key Features

-   **Autonomous Art Agents**: Each artwork uploaded to arweave spawns its own AO process with AI capabilities
-   **Peer-to-Peer Discovery**: Agents find relationships without centralized sorting. 
-   **Dual Mapping Modes**:
    -   **Scholar Map**: mapping based on content: Analyzes content, themes, and literary techniques
    -   **Mystic Map**: mapping based on creator persona: Explores the author's voice, soul essence, and purpose (coming soon)
-   **Verifiable AI Analysis**: Using APUS Network's on-chain inference
-   **Permanent Storage**: All artworks and relationships stored on Arweave
-   **Interactive Visualization**: Clickable relationship lines with detailed comparisons
-   **Living Network**: Map evolves as new artworks join

### 🏗️ Architecture

```

┌───────────────────────┐
│      Frontend UI      │
│  (user action + view) │
└───────────┬───────────┘
            │
            │ 1) Upload text → Arweave (gets txid)
            │
            ▼
┌───────────────────────┐
│     Arweave (L1)      │
│  stores artwork txid  │
└───────────┬───────────┘
            │
            │ 2) Frontend spawns Art Agent with {txid}
            ▼
┌───────────────────────┐
│      Art Agent        │
│  (for that Arweave    │
│        txid)          │
└───┬───────────────────┘
    │
    │ 3) Self-Analysis (verifiable)
    │
    │    ┌───────────────────────┐
    └───▶│       APUS AI         │
         │   verifiable infer    │
         └───────────────────────┘

    4) Register with Coordinator  ───────────────────────────────┐
    (after self-analysis)                                         │
    and request 10 random peers                                   │
                                                                  ▼
                       ┌───────────────────────────┐
                       │   Coordinator Agent       │
                       │ - holds full map +        │
                       │   agent registry          │
                       │ - returns random peers    │
                       │ - serves map to frontend  │
                       └───────────┬───────────────┘
                                   │
                     5) returns 10 random peers
                                   │
                                   ▼
        ┌───────────────────────────────────────────────────────────┐
        │                  P2P Relationship Phase                   │
        │                                                           │
        │  Art Agent ──talks directly to──► Peer Agents (10 seeds)  │
        │     │                          ◄──talk back────────────── │
        │     │                                                     │
        │     ├─ analyze pairwise via APUS                          │
        │     ├─ decide edge type (duplicate/version/sibling/       │
        │     │                 cousin/distant cousin)              │
        │     └─ expand search via peers’ siblings/cousins          │
        └───────────────────────────────────────────────────────────┘

    6) After each edge decision:
       ├─ (optional) persist attestation → Arweave
       └─ notify Coordinator with new edge

            ┌───────────────────────┐
            │     Arweave (L1)      │◄─── edge/analysis attestation (opt.)
            └───────────────────────┘

                       ┌───────────────────────────┐
                       │   Coordinator Agent       │
                       │ - updates global graph    │
                       │ - maintains registry      │
                       └───────────┬───────────────┘
                                   │
                                   │ 7) “Request Map”
                                   │    (from Frontend)
                                   ▼
┌───────────────────────┐  ◄───────┘
│      Frontend UI      │
│  render Map of Soul   │
└───────────────────────┘


```

### 🚀 Quick Start

1.  **Deploy the Coordinator and art agent**

```
aos coordinator
.load coordinator.lua

```
```
aos art_agent_yourart
.load art_agent.lua

```

1.  **Set up APUS AI** (1000 credits available)

```
# Process ID: A5TeWstBP1mD3FiZoU9JrbFUQ9Xg-hBgxHT7oeEVMr0

```

1.  **Upload Artwork**

-   Use the UI to upload text, title, and icon
-   Art agent spawns automatically
-   Watch as it discovers its family

### 📁 Repository Structure

```
map-of-the-soul/
├── ao/
│   ├── art_agent.lua          # Autonomous agent for each artwork
│   ├── coordinator.lua         # Central map coordinator
│   ├── config/
│   │   ├── metrics_config.lua # Relationship thresholds & categories
│   │   └── process_config.lua # Process IDs & settings
│   ├── prompts/
│   │   └── scholar_prompts.lua # LLM prompts for analysis
│   └── utils/
│       ├── scholar_utils.lua      # Analysis parsing
│       ├── relationship_analyzer.lua # Peer comparison logic
│       ├── discovery_manager.lua  # P2P discovery management
│       ├── gemma_interface.lua    # APUS AI integration
│       └── arweave_storage.lua    # Permanent storage
├── frontend/
│   └── index.html             # Interactive map visualization
|   ├── styles.css 
|   └── script.js    
└── README.md

```

### 🎯 How It Works

1.  **Artwork Upload**: Text is stored on Arweave, spawning an art agent
2.  **Self-Analysis**: Agent uses AI to analyze emotional tone, themes, style etc.
3.  **Peer Discovery**: Agent communicates P2P to find related artworks
4.  **Relationship Formation**: AI determines relationship type (sibling, cousin, etc.)
5.  **Map Update**: Coordinator updates the visual map
6.  **Continuous Evolution**: New artworks reshape existing relationships

### 🔮 Scholar Map Metrics

-   **Analysis Categories**:
    -   Emotional tone and thematic elements
    -   Stylistic influence and canonical position
    -   Hidden insights and overlooked details that make an artpiece undeniably unique
-   **Relationship Types**:
    -   Duplicate (100% match)
    -   Version (90%+ similar)
    -   Sibling (70-89% - same voice/content)
    -   Cousin (50-69% - thematic kinship)
    -   Distant Cousin (30-49% - subtle resonances)

### 🌙 Mystic Map (Coming Soon)

-   **Analysis Categories**:
    -   Zodiac archetype of writer's voice and perspective
    -   Soul signature and essence of the author
    -   Mythos and impact of the narrative perspective on humanity
-   **Relationship Types**:
    -   Soul Twin (deep resonance in soul signature and mythos)
    -   Soul Mate (similar soul essences or mythos)
    -   Karmic (polarized opposites: similar themes/voices, opposite perspectives)

### 💡 Use Cases

-   **Digital Libraries**: Self-organizing collections (also helpful for training llms)
-   **NFT Marketplaces**: Trace provenance of ideas
-   **Social Platforms**: Enhanced content discovery
-   **Creative Communities**: Find artistic kindred spirits
-   **Academic Research**: Explore literary connections

### 🛠️ Technical Stack

-   **AO**: Autonomous compute processes
-   **Arweave**: Permanent storage
-   **APUS Network**: Verifiable AI inference
-   **Lua**: Agent logic
-   **HTML/CSS/JavaScript**: Frontend visualization

### 📊 Hackathon Category

**Multi-Agent Systems** - Each artwork spawns an autonomous agent that communicates peer-to-peer to build emergent networks.

**License** - MIT License