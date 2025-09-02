Map of the Soul - README
========================

Autonomous Art Agents Creating Self-Organizing Literary Networks on AO
----------------------------------------------------------------------

### 🎨 Overview

Map of the Soul is a revolutionary multi-agent system that transforms how we understand relationships between creative works. When text artwork is uploaded to Arweave, it spawns an autonomous AI agent that analyzes itself, discovers its literary family through peer-to-peer communication, and contributes to an ever-evolving map of creative connections.

Unlike traditional content analysis that relies on centralized categorization, Map of the Soul allows artworks to self-organize into organic networks of meaning, creating what we call a "literary democracy" where each piece actively participates in defining its place in the cultural landscape.

### 🌟 Key Features

-   **Autonomous Art Agents**: Each artwork spawns its own AO process with AI capabilities
-   **Peer-to-Peer Discovery**: Agents find relationships without centralized sorting
-   **Dual Mapping Modes**:
    -   **Scholar Map**: Analyzes content, themes, and literary techniques
    -   **Mystic Map**: Explores the author's voice, soul essence, and purpose (coming soon)
-   **Verifiable AI Analysis**: Using APUS Network's on-chain inference
-   **Permanent Storage**: All artworks and relationships stored on Arweave
-   **Interactive Visualization**: Clickable relationship lines with detailed comparisons
-   **Living Network**: Map evolves as new artworks join

### 🏗️ Architecture

```
┌─────────────────┐
│   Frontend UI   │
└────────┬────────┘
         │
┌────────▼────────┐
│  Coordinator    │◄──── Holds complete map
│     Agent       │      Manages positions
└────────┬────────┘      Stores relationships
         │
    ┌────▼────┐
    │  Art    │ ◄──── Self-analyzes content
    │ Agent 1 │ ◄──── Discovers peers P2P
    └────┬────┘       Stores on Arweave
         │
    P2P Communication
         │
    ┌────▼────┐
    │  Art    │
    │ Agent N │
    └─────────┘

```

### 🚀 Quick Start

1.  **Deploy the Coordinator**

```
aos coordinator
.load coordinator.lua

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
└── README.md

```

### 🎯 How It Works

1.  **Artwork Upload**: Text is stored on Arweave, spawning an art agent
2.  **Self-Analysis**: Agent uses AI to analyze emotional tone, themes, style
3.  **Peer Discovery**: Agent communicates P2P to find related artworks
4.  **Relationship Formation**: AI determines relationship type (sibling, cousin, etc.)
5.  **Map Update**: Coordinator updates the visual map
6.  **Continuous Evolution**: New artworks reshape existing relationships

### 🔮 Scholar Map Metrics

-   **Analysis Categories**:
    -   Emotional tone and thematic elements
    -   Stylistic influence and canonical position
    -   Hidden insights and overlooked details
-   **Relationship Types**:
    -   Duplicate (100% match)
    -   Version (90%+ similar)
    -   Sibling (70-89% - same voice/content)
    -   Cousin (50-69% - thematic kinship)
    -   Distant Cousin (30-49% - subtle resonances)

### 🌙 Mystic Map (Coming Soon)

-   **Analysis Categories**:
    -   Zodiac archetype of writer's voice
    -   Soul signature and essence
    -   Mythos and impact on humanity
-   **Relationship Types**:
    -   Soul Twin (deep resonance)
    -   Soul Mate (complementary essences)
    -   Karmic (polarized opposites)

### 💡 Use Cases

-   **Digital Libraries**: Self-organizing collections
-   **NFT Marketplaces**: Trace provenance of ideas
-   **Social Platforms**: Enhanced content discovery
-   **Creative Communities**: Find artistic kindred spirits
-   **Academic Research**: Explore literary connections

### 🛠️ Technical Stack

-   **AO**: Autonomous compute processes
-   **Arweave**: Permanent storage
-   **APUS Network**: Verifiable AI inference
-   **Lua**: Agent logic
-   **JavaScript**: Frontend visualization

### 📊 Hackathon Category

**Multi-Agent Systems** - Each artwork spawns an autonomous agent that communicates peer-to-peer to build emergent networks.

**License** - MIT License