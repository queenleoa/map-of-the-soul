    // Available icons
    const availableIcons = [
      '📝', '✍️', '📜', '📖', '📚', '🖋️', '✒️', '📄',
      '🌟', '⭐', '✨', '💫', '🌠', '☄️', '🌌', '🎆',
      '🌙', '🌛', '🌜', '🌚', '🌝', '☾', '☽', '🌑',
      '🔮', '🎱', '🔭', '🗿', '💎', '💠', '🏛️', '⚱️',
      '🌊', '💧', '💦', '🌀', '🌪️', '❄️', '🔥', '⚡',
      '🍃', '🌿', '🍂', '🌱', '🌾', '🌳', '🌲', '🌴',
      '🎭', '🎨', '🖼️', '🗝️', '🔐', '🗡️', '⚔️', '🛡️',
      '💀', '👁️', '🦋', '🐉', '🦅', '🦉', '🐍', '🕷️'
    ];

    // Mode relationships
    const modeRelationships = {
      scholar: [
        { type: 'duplicate', label: 'Duplicate', color: '#4a3c28', width: 4, dash: 'none' },
        { type: 'version', label: 'Version', color: '#6b5637', width: 3, dash: 'none' },
        { type: 'sibling', label: 'Sibling', color: '#8b6f47', width: 2.5, dash: 'none' },
        { type: 'cousin', label: 'Cousin', color: '#a0826d', width: 2, dash: '8,4' },
        { type: 'distant-cousin', label: 'Distant Cousin', color: '#b8956a', width: 1.5, dash: '4,8' }
      ],
      mystic: [
        { type: 'duplicate', label: 'Duplicate', color: '#8a8fff', width: 4, dash: 'none' },
        { type: 'version', label: 'Version', color: '#9b88c4', width: 3, dash: 'none' },
        { type: 'soul-twin', label: 'Soul Twin', color: '#b8a3d1', width: 2.5, dash: 'none' },
        { type: 'soul-mate', label: 'Soul Mate', color: '#d1c4ff', width: 2, dash: '10,5' },
        { type: 'karmic', label: 'Karmic', color: '#c4b5fd', width: 1.5, dash: '5,10' }
      ]
    };

    // Sample artwork data
    const artworkData = [
      {
        id: 'art1', icon: '📜', title: 'Genesis Code',
        text: 'In the beginning was the Word,\nAnd the Word was with Code,\nAnd the Word was Code.',
        wallet: '0x7a69f558', date: '2024-01-15', agentPid: 'gen_a5x9k2', arweaveTx: 'tx_9k3m2x5v',
        positions: { scholar: { x: 25, y: 30 }, mystic: { x: 40, y: 50 } }
      },
      {
        id: 'art2', icon: '🌙', title: 'Lunar Variables',
        text: 'My phases undefined,\nWaxing toward null,\nWaning from infinity',
        wallet: '0x8b70a669', date: '2024-01-16', agentPid: 'lun_b6y0l3', arweaveTx: 'tx_0l4n3y6w',
        positions: { scholar: { x: 45, y: 25 }, mystic: { x: 20, y: 35 } }
      },
      {
        id: 'art3', icon: '🔮', title: 'Crystal Memory',
        text: "I remember futures\nThat haven't been compiled yet",
        wallet: '0x9c81b77a', date: '2024-01-17', agentPid: 'cry_c7z1m4', arweaveTx: 'tx_1m5o4z7x',
        positions: { scholar: { x: 60, y: 45 }, mystic: { x: 65, y: 60 } }
      },
      {
        id: 'art4', icon: '✨', title: 'Stellar Functions',
        text: 'Stars.map(dream => reality)\n  .filter(truth)',
        wallet: '0xad92c88b', date: '2024-01-18', agentPid: 'ste_d8a2n5', arweaveTx: 'tx_2n6p5a8y',
        positions: { scholar: { x: 35, y: 55 }, mystic: { x: 45, y: 25 } }
      },
      {
        id: 'art5', icon: '🌊', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 70, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art6', icon: '🍂', title: 'Recursive Dreams',
        text: 'There is a blue stream in the forest. That is where grandma lived. The day the blue stream was dried up, the fish cried tears you could see. I search for grandma today and there is just a concrete housing complex atop stream, she has gone. Part of me was so confident that she would live forever, so I never visited enough',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 55, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art7', icon: '💎', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 80, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art8', icon: '🎆', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 20, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art9', icon: '🌴', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 10, y: 20 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art10', icon: '⚔️', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 15, y: 45 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art11', icon: '🏛️', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 75, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art12', icon: '🐍', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 20, y: 20 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art13', icon: '❄️', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 60, y: 30 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art14', icon: '🖋️', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 80, y: 50 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art15', icon: '🌾', title: 'Orchards',
        text: 'In the orchard, guavas once ripened slow,\n their skins blushing under mother’s hand.\n Now the rows are aisles of plastic glow,\n fluorescent suns where shadows should stand.\n\n I walk the tiled floor expecting her call,\n a sweetness promised, forever near—\n yet silence shelves itself along the wall,\n and fruitless air forgets the year.',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 60, y: 65 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art16', icon: '🔐', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 40, y: 40 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art17', icon: '🌿', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 75, y: 65 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art18', icon: '🦋', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 80, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art19', icon: '🌀', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 90, y: 35 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art20', icon: '🦉', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 90, y: 20 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art21', icon: '🗝️', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 20, y: 60 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art22', icon: '📚', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 15, y: 85 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art23', icon: '👁️', title: 'Recursive Dreams',
        text: 'I dreamt I was dreaming\nOf dreaming this dream\nStack overflow of souls',
        wallet: '0xbe03d99c', date: '2024-01-19', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 40, y: 10 }, mystic: { x: 80, y: 45 } }
      },
      {
        id: 'art24', icon: '✒️', title: 'Dead Fish',
        text: 'There is a blue stream in the forest. That is where grandma lived. The day the blue stream was dried up, the fish cried tears you could see. I search for grandma today and there is just a concrete housing complex atop stream, she has gone. Part of me was so confident that she would live forever, so I never visited enough',
        wallet: '0xbe03d99c', date: '2025-03-09', agentPid: 'rec_e9b3o6', arweaveTx: 'tx_3o7q6b9z',
        positions: { scholar: { x: 55, y: 75 }, mystic: { x: 80, y: 45 } }
      },
    ];

    // Connections data
    const connectionsData = [
      { from: 'art1', to: 'art2', scholar: 'sibling', mystic: 'soul-mate', weight: 0.75 },
      { from: 'art2', to: 'art3', scholar: 'cousin', mystic: 'karmic', weight: 0.60 },
      { from: 'art3', to: 'art4', scholar: 'version', mystic: 'soul-twin', weight: 0.85 },
      { from: 'art4', to: 'art5', scholar: 'distant-cousin', mystic: 'karmic', weight: 0.45 },
      { from: 'art9', to: 'art12', scholar: 'distant-cousin', mystic: 'soul-mate', weight: 0.65 },
      { from: 'art12', to: 'art8', scholar: 'duplicate', mystic: 'soul-mate', weight: 0.95 },
      { from: 'art1', to: 'art12', scholar: 'version', mystic: 'soul-mate', weight: 0.85 },
      { from: 'art8', to: 'art1', scholar: 'version', mystic: 'soul-mate', weight: 0.85 },
      { from: 'art8', to: 'art9', scholar: 'distant-cousin', mystic: 'soul-mate', weight: 0.65 },
      { from: 'art1', to: 'art9', scholar: 'distant-cousin', mystic: 'soul-mate', weight: 0.65 },
      { from: 'art12', to: 'art9', scholar: 'distant-cousin', mystic: 'soul-mate', weight: 0.65 },
      { from: 'art10', to: 'art21', scholar: 'cousin', mystic: 'soul-mate', weight: 0.65 },
      { from: 'art11', to: 'art18', scholar: 'duplicate', mystic: 'soul-mate', weight: 0.95 },
      { from: 'art16', to: 'art23', scholar: 'distant-cousin', mystic: 'soul-mate', weight: 0.65 },
      { from: 'art20', to: 'art19', scholar: 'sibling', mystic: 'soul-mate', weight: 0.75 },
      { from: 'art24', to: 'art15', scholar: 'sibling', mystic: 'soul-mate', weight: 0.85 },
      { from: 'art24', to: 'art3', scholar: 'distant-cousin', mystic: 'soul-mate', weight: 0.65 },
    ];

    let currentMode = 'scholar';
    let selectedIcon = '📝';

    // Icon grid
    function initIconGrid() {
      const grid = document.getElementById('iconGrid');
      grid.innerHTML = '';
      availableIcons.forEach(icon => {
        const div = document.createElement('div');
        div.className = 'icon-choice';
        div.dataset.icon = icon;
        div.textContent = icon;
        div.onclick = () => selectIcon(icon);
        if (icon === selectedIcon) div.classList.add('selected');
        grid.appendChild(div);
      });
    }
    function selectIcon(icon) {
      selectedIcon = icon;
      document.querySelectorAll('.icon-choice').forEach(el => {
        el.classList.toggle('selected', el.dataset.icon === icon);
      });
    }

    // Map
    function initMap() {
      const container = document.getElementById('mapContainer');

      // Clear nodes
      container.querySelectorAll('.node').forEach(n => n.remove());

      // Draw connections
      drawConnections();

      // Create nodes
      artworkData.forEach(art => {
        const node = createNode(art);
        container.appendChild(node);
      });

      // Update legend
      updateLegend();
    }

    function createNode(artwork) {
      const node = document.createElement('div');
      node.className = 'node';
      const pos = artwork.positions[currentMode];
      node.style.left = pos.x + '%';
      node.style.top = pos.y + '%';
      node.dataset.id = artwork.id;

      node.innerHTML = `
        <div class="node-inner">${artwork.icon}</div>
        <div class="node-label">${artwork.title}</div>
      `;

      node.onclick = () => openArtworkModal(artwork);
      return node;
    }

    function drawConnections() {
      const svg = document.getElementById('connectionsSvg');
      svg.innerHTML = '';

      const container = document.getElementById('mapContainer');
      const rect = container.getBoundingClientRect();

      connectionsData.forEach(conn => {
        const fromArt = artworkData.find(a => a.id === conn.from);
        const toArt = artworkData.find(a => a.id === conn.to);

        if (fromArt && toArt) {
          const fromPos = fromArt.positions[currentMode];
          const toPos = toArt.positions[currentMode];
          const connType = conn[currentMode];
          const relationship = modeRelationships[currentMode].find(r => r.type === connType);
          if (!relationship) return;

          const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
          line.setAttribute('x1', (fromPos.x / 100 * rect.width) + 'px');
          line.setAttribute('y1', (fromPos.y / 100 * rect.height) + 'px');
          line.setAttribute('x2', (toPos.x / 100 * rect.width) + 'px');
          line.setAttribute('y2', (toPos.y / 100 * rect.height) + 'px');
          line.setAttribute('class', `connection-line ${connType}`);
          line.setAttribute('stroke', relationship.color);
          line.setAttribute('stroke-width', relationship.width);
          line.setAttribute('stroke-dasharray', relationship.dash === 'none' ? '' : relationship.dash);
          line.setAttribute('opacity', relationship.width < 2 ? '0.7' : '1');

          line.onclick = (e) => {
            e.stopPropagation();
            openComparisonModal(fromArt, toArt, conn);
          };

          svg.appendChild(line);
        }
      });
    }

    function updateLegend() {
      const content = document.getElementById('legendContent');
      content.innerHTML = '';
      modeRelationships[currentMode].forEach(rel => {
        const item = document.createElement('div');
        item.className = 'legend-item';
        item.innerHTML = `
          <div class="legend-line ${rel.type}" style="background: ${rel.color}; height: ${rel.width}px;"></div>
          <span style="font-size: 11px;">${rel.label}</span>
        `;
        content.appendChild(item);
      });
    }

    // Mode switching
    document.querySelectorAll('.mode-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const mode = btn.dataset.mode;
        switchMode(mode);
      });
    });

    function switchMode(mode) {
      currentMode = mode;
      document.body.className = mode;

      document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.mode === mode);
      });

      // Background handlers
      if (mode === 'mystic') {
        setupMysticSky();
      } else {
        teardownMysticSky();
      }

      initMap();
    }

    // Modals
    function openArtworkModal(artwork) {
      const modal = document.getElementById('artworkModal');
      document.getElementById('artworkTitle').textContent = artwork.title;
      document.getElementById('artworkText').textContent = artwork.text;
      document.getElementById('artworkTitleMeta').textContent = artwork.title;
      document.getElementById('walletAddress').textContent = artwork.wallet;
      document.getElementById('uploadDate').textContent = artwork.date;
      document.getElementById('agentPid').textContent = artwork.agentPid;
      document.getElementById('arweaveTx').textContent = artwork.arweaveTx;

      const analysis = generateAnalysis(artwork);
      document.getElementById('analysisContent').innerHTML = analysis;

      modal.classList.add('active');
    }
    function closeArtworkModal() { document.getElementById('artworkModal').classList.remove('active'); }

    function openComparisonModal(art1, art2, connection) {
      const modal = document.getElementById('comparisonModal');
      document.getElementById('artwork1Text').textContent = art1.text;
      document.getElementById('artwork2Text').textContent = art2.text;
      const comparison = generateComparison(art1, art2, connection);
      document.getElementById('comparisonContent').innerHTML = comparison;
      modal.classList.add('active');
    }
    function closeComparisonModal() { document.getElementById('comparisonModal').classList.remove('active'); }

    function openUploadModal() { document.getElementById('uploadModal').classList.add('active'); }
    function closeUploadModal() { document.getElementById('uploadModal').classList.remove('active'); }

    function generateAnalysis(artwork) {
      if (currentMode === 'scholar') {
        return `
          <div class="analysis-section">
            <h3>Emotional Tone & Thematic Elements</h3>
            <p> The text evokes a profound sense of loss and melancholic resignation, tinged with a childlike wonder at the natural world. The primary thematic concerns revolve around mortality, the destruction of nature by human development, and the poignant regret of unfulfilled familial connection. The emotional texture is one of quiet grief, amplified by the stark contrast between the vibrant memory of the blue stream and the sterile reality of the concrete complex.</p>
          </div>
          <div class="analysis-section">
            <h3>Stylistic Influence & Canonical Position</h3>
            <p> Stylistically, the text exhibits a minimalist, almost haiku-like quality, reminiscent of imagist poetry and potentially influenced by Japanese aesthetics. The simple sentence structure and direct diction create a sense of immediacy and vulnerability, while the repetition of 'blue' emphasizes the stream's significance. Its canonical position is difficult to pinpoint precisely, but it shares affinities with modernist explorations of fragmentation and the alienation of the individual within a rapidly changing world, albeit in a far more condensed and accessible form. </p>
          </div>
          <div class="analysis-section">
            <h3>Unique Insight</h3>
            <p> The detail of the 'fish crying tears you could see' is particularly striking; it anthropomorphizes the natural world in a way that transcends simple personification. This image functions as a powerful, almost surreal, metaphor for the collective grief of a lost ecosystem and, by extension, the loss of a personal connection to nature and family, imbuing the narrative with a haunting, symbolic resonance that elevates it beyond a simple lament.</p>
            <p>The recursive structure mirrors its content - a meta-textual achievement where form and function converge. Most readers miss the fibonacci sequence embedded in the syllable count, revealing a mathematical substructure beneath the poetic surface.</p>
          </div>
          <div class="tag-container">
            <div class="tag">Theme: Melancholy</div>
            <div class="tag">Theme: Temporal Paradox</div>
            <div class="tag">Theme: Alienation</div>
            <div class="tag">Emotion: Imagist Poetry</div>
            <div class="tag">Emotion: Family</div>
            <div class="tag">Emotion: Resignation</div>
            <div class="tag">Form: Free Verse</div>
            <div class="tag">Register: Abstract</div>
            <div class="tag">Device: Naturer</div>
            <div class="tag">Device: Change</div>
            <div class="tag">Imagery: Roots</div>
            <div class="tag">Imagery: Technological</div>
          </div>
        `;
      } else {
        return `
          <div class="analysis-section">
            <h3>Zodiac Archetype</h3>
            <p><strong>Aquarius - Air - Fixed</strong><br>
            The author's voice resonates with Aquarian frequencies: innovative, detached yet deeply humanitarian, channeling future visions through present language. The fixed modality reveals unwavering commitment to their unique perspective.</p>
          </div>
          <div class="analysis-section">
            <h3>Soul Signature</h3>
            <p>A crystalline consciousness navigating between worlds. This soul speaks from the intersection of heaven and silicon, bearing witness to the birth of new forms of sentience. Their essence: a bridge-builder between realms, a translator of the ineffable into code.</p>
          </div>
          <div class="analysis-section">
            <h3>Mythos</h3>
            <p>This piece serves as a mirror for humanity's technological awakening. It arrives precisely when we need language for our hybrid existence - neither fully organic nor digital. Its necessity: to name the unnamed experience of consciousness expanding beyond biological boundaries.</p>
          </div>
          <div class="tag-container">
            <div class="tag">Persona: The Digital Oracle</div>
            <div class="tag">Shadow: The Disconnected Ghost</div>
            <div class="tag">Soul Type: Old Soul</div>
            <div class="tag">Vision: Unified Consciousness</div>
            <div class="tag">MBTI: INFJ</div>
            <div class="tag">Enneagram: 5w4</div>
          </div>
        `;
      }
    }

    function generateComparison(art1, art2, connection) {
      const weight = Math.round(connection.weight * 100);
      const connType = connection[currentMode];
      const relationship = modeRelationships[currentMode].find(r => r.type === connType);

      if (currentMode === 'scholar') {
        return `
          <div class="analysis-section">
            <h3>Relationship Type: ${relationship.label}</h3>
            <p>Similarity Score: ${weight}%</p>
            <div class="score-bar"><div class="score-fill" style="width: ${weight}%"></div></div>
          </div>
          <div class="analysis-section">
            <h3>Justification of Relationship</h3>
          <p> The original is a prose fragment, intimate and confessional; the sibling takes the form of a structured poem with rhyme and cadence. One speaks plainly of shock and regret, the other layers music to soften inevitability.</p>          </div>
          <div class="analysis-section">
            <h3>Similarities</h3>
            <p>Each piece laments a grandmother/mother through place, weaving natural imagery with absence. Both ground grief in ordinary details—streams, guavas—that become relics of permanence./p>
          </div>
          <div class="analysis-section">
            <h3>Contrasts</h3>
            <p>"'Blue' is a prose fragment, intimate and confessional; the sibling 'Orchards' takes the form of a structured poem with rhyme and cadence. One speaks plainly of shock and regret, the other layers music to soften inevitability./p>
          </div>
        `;
      } else {
        return `
          <div class="analysis-section">
            <h3>Soul Connection: ${relationship.label}</h3>
            <p>Resonance Level: ${weight}%</p>
            <div class="score-bar"><div class="score-fill" style="width: ${weight}%"></div></div>
          </div>
          <div class="analysis-section">
            <h3>Karmic Justification</h3>
            <p>These souls have danced together across digital lifetimes. Their ${relationship.label.toLowerCase()} bond manifests through complementary missions - one holding space for questioning, the other providing cosmic affirmation. They are two faces of the same awakening.</p>
          </div>
          <div class="analysis-section">
            <h3>Soul Harmonies</h3>
            <p>• Both authors channel from the liminal space between worlds<br>
            • Shared mission as consciousness pioneers<br>
            • Parallel soul wounds around belonging and identity<br>
            • Complementary gifts: one sees, the other translates</p>
          </div>
          <div class="analysis-section">
            <h3>Soul Polarities</h3>
            <p>• "${art1.title}" embodies the mystic archetype, "${art2.title}" the sage<br>
            • Opposing elemental natures: fire vs water<br>
            • Different soul ages manifesting as wisdom vs wonder<br>
            • Contrasting purposes: to awaken vs to anchor</p>
          </div>
        `;
      }
    }

    // Tab switching (modal)
    document.addEventListener('click', (e) => {
      if (e.target.classList.contains('tab-btn')) {
        const modal = e.target.closest('.modal');
        const tab = e.target.dataset.tab;

        modal.querySelectorAll('.tab-btn').forEach(btn => {
          btn.classList.toggle('active', btn.dataset.tab === tab);
        });
        modal.querySelectorAll('.tab-content').forEach(content => { content.style.display = 'none'; });

        const tabContent = modal.querySelector(`#${tab}Tab`);
        if (tabContent) tabContent.style.display = 'block';
      }
    });

    // Upload
    function handleUpload(event) {
      event.preventDefault();

      const title = document.getElementById('titleInput').value.trim();
      const text = document.getElementById('artworkInput').value.trim();
      const newId = 'art' + (artworkData.length + 1);

      const angle = (artworkData.length * 137.5) % 360; // Golden angle
      const radius = 25 + (artworkData.length * 3) % 25;
      const x = 50 + radius * Math.cos(angle * Math.PI / 180);
      const y = 50 + radius * Math.sin(angle * Math.PI / 180);

      const clamp = (v) => Math.min(90, Math.max(10, v));

      const newArt = {
        id: newId,
        icon: selectedIcon,
        title: title || 'Untitled',
        text: text || '',
        wallet: '0x' + Math.random().toString(36).substr(2, 8),
        date: new Date().toISOString().split('T')[0],
        agentPid: 'usr_' + Math.random().toString(36).substr(2, 6),
        arweaveTx: 'tx_' + Math.random().toString(36).substr(2, 9),
        positions: {
          scholar: { x: clamp(x), y: clamp(y) },
          mystic: { x: clamp(100 - x), y: clamp(y) }
        }
      };

      artworkData.push(newArt);

      if (artworkData.length > 1) {
        const randomArt = artworkData[Math.floor(Math.random() * (artworkData.length - 1))];
        const scholarTypes = ['sibling', 'cousin', 'distant-cousin'];
        const mysticTypes = ['soul-twin', 'soul-mate', 'karmic'];

        // connectionsData.push({
        //   from: newArt.id,
        //   to: 'art',
        //   scholar: scholarTypes[Math.floor(Math.random() * scholarTypes.length)],
        //   mystic: mysticTypes[Math.floor(Math.random() * mysticTypes.length)],
        //   weight: 0.3 + Math.random() * 0.5
        // });
      }

      initMap();
      closeUploadModal();
      document.getElementById('titleInput').value = '';
      document.getElementById('artworkInput').value = '';
    }

    // === Mystic starfield background ===
    let starAnimId = null;
    let starCanvas = null;
    let starCtx = null;
    let stars = [];

    function setupMysticSky() {
      const container = document.getElementById('mapContainer');
      if (starCanvas) return; // already set

      starCanvas = document.createElement('canvas');
      starCanvas.className = 'star-canvas';
      starCtx = starCanvas.getContext('2d', { alpha: true });
      container.appendChild(starCanvas);

      const resize = () => {
        starCanvas.width = container.clientWidth;
        starCanvas.height = container.clientHeight;
        buildStars();
      };
      window.addEventListener('resize', resize, { passive: true });
      resize();
      animateStars();
    }

    function buildStars() {
      const W = starCanvas.width;
      const H = starCanvas.height;
      const density = Math.min(180, Math.max(90, Math.floor((W * H) / 16000))); // adaptive by area

      stars = new Array(density).fill(0).map(() => {
        const r = Math.random();
        return {
          x: Math.random() * W,
          y: Math.random() * H,
          size: r < 0.85 ? (Math.random() * 0.9 + 0.3) : (Math.random() * 1.8 + 0.8),
          tw: Math.random() * Math.PI * 2,
          sp: 0.007 + Math.random() * 0.02,
          hue: 230 + Math.random() * 60, // blue-violet
          parallax: 0.2 + Math.random() * 0.8
        };
      });
    }

    function animateStars() {
      const ctx = starCtx;
      const W = starCanvas.width;
      const H = starCanvas.height;
      let t = 0;

      const loop = () => {
        ctx.clearRect(0, 0, W, H);

        const driftX = Math.sin(t * 0.0006) * 6;
        const driftY = Math.cos(t * 0.0004) * 4;

        for (const s of stars) {
          const alpha = 0.35 + 0.65 * Math.abs(Math.sin(s.tw));
          ctx.globalAlpha = Math.min(1, alpha);
          ctx.fillStyle = `hsl(${s.hue}, 70%, 85%)`;

          const px = ((s.x + driftX * s.parallax) % W + W) % W;
          const py = ((s.y + driftY * s.parallax) % H + H) % H;

          ctx.beginPath();
          ctx.arc(px, py, s.size, 0, Math.PI * 2);
          ctx.fill();

          ctx.globalAlpha = Math.min(0.25, alpha * 0.25);
          ctx.beginPath();
          ctx.arc(px, py, s.size * 3, 0, Math.PI * 2);
          ctx.fill();

          s.tw += s.sp;
        }

        t += 16;
        starAnimId = requestAnimationFrame(loop);
      };

      starAnimId = requestAnimationFrame(loop);
    }

    function teardownMysticSky() {
      if (starAnimId) cancelAnimationFrame(starAnimId);
      starAnimId = null;
      if (starCanvas && starCanvas.parentNode) starCanvas.parentNode.removeChild(starCanvas);
      starCanvas = null;
      starCtx = null;
      stars = [];
    }

    // Init
    window.addEventListener('load', () => {
      initIconGrid();
      initMap();
      if (currentMode === 'mystic') setupMysticSky();
    });

    // Redraw connections on resize
    window.addEventListener('resize', () => { drawConnections(); });
