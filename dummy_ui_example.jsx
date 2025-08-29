import React, { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Search, Plus, Sparkles, Info, Wand2, Upload } from "lucide-react";

/**
 * Mystical genome-map UI demo (front-end only)
 * - Parchment map look
 * - Nodes connected by genome-like edges (varying length/weight)
 * - Hover tooltips + click to open AI-conversation card
 * - "Add your art" modal visually spawns a new node and mock edges
 * - No backend / AO wiring — UI scaffolding for the hackathon demo
 */

// --- Demo data -------------------------------------------------------------
const CLUSTERS = [
  { id: "myths", label: "Solar Myths", center: { x: 18, y: 36 }, hue: 38, lore: "Ritual suns, cyclical motifs." },
  { id: "dreams", label: "Nocturne Dreams", center: { x: 55, y: 52 }, hue: 266, lore: "Moonlit inner monologues." },
  { id: "city",  label: "Urban Memory",  center: { x: 80, y: 28 }, hue: 201, lore: "Transit rhythms, neon echoes." },
];

const INITIAL_NODES = [
  n(1, "Sun Hymn #3", "image", "myths", 12, 30, [
    ["Sun Hymn #3", "I orbit you. You call, I burn."],
    ["Cedar Relic", "We share the circle motif — cousins, perhaps."],
  ]),
  n(2, "Cedar Relic", "image", "myths", 22, 38, [
    ["Cedar Relic", "Resin time, spiral growth."],
    ["Sun Hymn #3", "Spiral to circle to halo."],
  ]),
  n(3, "Glyphs for Dawn", "text", "myths", 16, 44, [
    ["Glyphs", "Horizon = promise. Flame = will."],
    ["Sun Hymn #3", "Promise and will — family resemblance."],
  ]),
  n(4, "Pillow-Lake", "image", "dreams", 49, 58, [
    ["Pillow-Lake", "I blur the shoreline until it is a feeling."],
    ["Night Ledger", "I keep the feeling as an entry."],
  ]),
  n(5, "Night Ledger", "text", "dreams", 60, 50, [
    ["Night Ledger", "page 37: the moon smelled like cedar."],
    ["Pillow-Lake", "We touched the same tree in sleep."],
  ]),
  n(6, "Moth in the Atrium", "image", "dreams", 54, 43, [
    ["Moth", "Light makes a cathedral of dust."],
    ["Pillow-Lake", "And the nave is your wing."],
  ]),
  n(7, "Metro Psalm", "text", "city", 77, 22, [
    ["Metro Psalm", "Staccato stations, breath between stops."],
    ["Neon Palimpsest", "Your cadence tags my wall."],
  ]),
  n(8, "Neon Palimpsest", "image", "city", 85, 31, [
    ["Neon", "I rewrite light over light."],
    ["Metro Psalm", "We loop the same refrain."],
  ]),
  n(9, "Archive of Puddles", "image", "city", 73, 34, [
    ["Puddles", "Skylines learn to swim."],
    ["Neon Palimpsest", "Your reflections are my ink."],
  ]),
];

const INITIAL_EDGES: Edge[] = [
  e("1-2", 1, 2, 0.92, "halo/spiral kin"),
  e("1-3", 1, 3, 0.72, "dawn glyphs"),
  e("2-3", 2, 3, 0.58, "wood/fire cycles"),
  e("4-5", 4, 5, 0.86, "shared cedar-moon"),
  e("4-6", 4, 6, 0.74, "blurred light"),
  e("5-6", 5, 6, 0.52, "ledger of dust"),
  e("7-8", 7, 8, 0.88, "transit/neon refrain"),
  e("7-9", 7, 9, 0.60, "rain cadence"),
  e("8-9", 8, 9, 0.66, "mirror ink"),
  // cross-family kinships
  e("3-5", 3, 5, 0.41, "dawn/diary scent"),
  e("6-9", 6, 9, 0.38, "dust/rain shimmer"),
];

// Types & helpers -----------------------------------------------------------
function n(
  id: number,
  title: string,
  type: "image" | "text",
  clusterId: string,
  x: number,
  y: number,
  whispers: [string, string][]
) {
  return {
    id,
    title,
    type,
    clusterId,
    x,
    y,
    whispers,
    tags: type === "image" ? ["composition", "texture", "symbolism"] : ["motif", "tone", "voice"],
  } as const;
}

type NodeT = ReturnType<typeof n>;

type Edge = { id: string; from: number; to: number; weight: number; note?: string };
function e(id: string, from: number, to: number, weight: number, note?: string): Edge {
  return { id, from, to, weight, note };
}

const clusterOf = (clusterId: string) => CLUSTERS.find((c) => c.id === clusterId)!;

// --- Components ------------------------------------------------------------
export default function ArtMapUI() {
  const [nodes, setNodes] = useState<NodeT[]>(INITIAL_NODES);
  const [edges, setEdges] = useState<Edge[]>(INITIAL_EDGES);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [query, setQuery] = useState("");
  const [showAdd, setShowAdd] = useState(false);

  const selected = useMemo(() => nodes.find((n) => n.id === selectedId) || null, [nodes, selectedId]);

  const nodeById = useMemo(() => Object.fromEntries(nodes.map((n) => [n.id, n])), [nodes]);

  const filteredNodes = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return nodes;
    return nodes.filter((n) => [n.title, n.clusterId, ...n.tags, ...n.whispers.flat()].some((s) => s.toLowerCase().includes(q)));
  }, [nodes, query]);

  const visibleIds = useMemo(() => new Set(filteredNodes.map((n) => n.id)), [filteredNodes]);

  const filteredEdges = useMemo(
    () => edges.filter((e) => visibleIds.has(e.from) && visibleIds.has(e.to)),
    [edges, visibleIds]
  );

  return (
    <div className="min-h-screen w-full text-stone-900 relative overflow-hidden">
      <ParchmentBackground />

      {/* Header */}
      <header className="pointer-events-none fixed top-0 left-0 right-0 z-30 flex items-start justify-between p-4 sm:p-6">
        <div className="pointer-events-auto">
          <TitleBadge />
        </div>
        <div className="pointer-events-auto flex items-center gap-2">
          <div className="hidden md:flex items-center gap-2 bg-stone-100/70 backdrop-blur rounded-2xl shadow-inner px-3 py-2 border border-stone-300/60">
            <SearchIcon />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search the genome… (motif, title, tone)"
              className="bg-transparent outline-none w-64 text-sm placeholder:text-stone-500"
            />
          </div>

          <button
            onClick={() => setShowAdd(true)}
            className="group inline-flex items-center gap-2 rounded-2xl border border-stone-400/60 bg-stone-100/80 backdrop-blur px-3 py-2 text-sm shadow hover:shadow-md hover:-translate-y-0.5 transition-all"
          >
            <Plus className="w-4 h-4" />
            Add your art
            <Sparkles className="w-4 h-4 opacity-60 group-hover:rotate-12 transition" />
          </button>
        </div>
      </header>

      {/* Map canvas */}
      <main className="relative z-10 mt-24 mb-8">
        <div className="relative mx-auto max-w-[1200px] h-[72vh] sm:h-[78vh] md:h-[80vh] lg:h-[82vh] rounded-3xl border border-stone-700/20 shadow-xl overflow-hidden">
          <MapSkin />

          {/* Subtle cluster labels (no halos) */}
          {CLUSTERS.map((c) => (
            <ClusterLabel key={c.id} cluster={c} />
          ))}

          {/* Edges layer (SVG) */}
          <EdgeOverlay nodes={nodes} edges={filteredEdges} selectedId={selectedId} />

          {/* Nodes */}
          {filteredNodes.map((node) => (
            <GenomeNode key={node.id} node={node} onSelect={() => setSelectedId(node.id)} selected={selectedId === node.id} />
          ))}

          <Legend />
        </div>
      </main>

      {/* Info card */}
      <AnimatePresence>{selected && <InfoCard key={selected.id} node={selected} edges={edges} nodeById={nodeById} onClose={() => setSelectedId(null)} />}</AnimatePresence>

      {/* Add-art modal */}
      <AnimatePresence>
        {showAdd && (
          <AddArtModal
            onClose={() => setShowAdd(false)}
            onSpawn={(newNode) => {
              // connect to 2 nearest nodes by Euclidean distance (visual only)
              const nearest = [...nodes]
                .map((n) => ({ n, d: dist(newNode, n) }))
                .sort((a, b) => a.d - b.d)
                .slice(0, 2)
                .map((x, i) => e(`${newNode.id}-${x.n.id}`, newNode.id, x.n.id, Math.max(0.35, 0.95 - 0.02 * i), "mock kinship"));
              setNodes((p) => [...p, newNode]);
              setEdges((p) => [...p, ...nearest]);
            }}
          />
        )}
      </AnimatePresence>

      {/* Footer */}
      <footer className="fixed bottom-3 inset-x-0 z-20 flex justify-center">
        <div className="text-[11px] tracking-widest uppercase text-stone-700/60 bg-stone-100/70 backdrop-blur rounded-xl px-3 py-1 border border-stone-300/60 shadow-sm">
          Map of the Soul — genome demo UI • lines = kinship; thickness = strength
        </div>
      </footer>
    </div>
  );
}

// --- UI Bits ---------------------------------------------------------------
function ParchmentBackground() {
  return (
    <div aria-hidden className="absolute inset-0 -z-10">
      <div className="absolute inset-0 bg-[radial-gradient(80%_50%_at_50%_0%,#f7f2e6_10%,#efe6d4_45%,#e4d8bf_70%,#d0c1a4_100%)]" />
      <div className="absolute inset-0 mix-blend-multiply opacity-[0.18]" style={{ backgroundImage: `repeating-linear-gradient(0deg, transparent 0 2px, rgba(0,0,0,.03) 2px 3px)` }} />
      <div className="absolute inset-0 bg-[radial-gradient(85%_70%_at_50%_40%,transparent_60%,rgba(51,39,13,0.28)_100%)]" />
      <div className="pointer-events-none absolute right-[-100px] bottom-[-100px] opacity-30 rotate-12">
        <CompassSVG size={420} />
      </div>
    </div>
  );
}

function MapSkin() {
  return (
    <div className="absolute inset-0">
      <div
        className="absolute inset-0 opacity-[0.18]"
        style={{
          backgroundImage:
            "linear-gradient(to right, rgba(78,59,32,.35) 1px, transparent 1px), linear-gradient(to bottom, rgba(78,59,32,.35) 1px, transparent 1px)",
          backgroundSize: "80px 80px",
          backgroundPosition: "center",
        }}
      />
      <div className="absolute inset-0 opacity-[0.12]" style={{ backgroundImage: "repeating-linear-gradient(90deg, transparent 0 160px, rgba(20,10,0,.25) 160px 161px)" }} />
      <svg className="absolute inset-0 w-full h-full" aria-hidden>
        <defs>
          <linearGradient id="topo" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="rgba(40,28,12,.20)" />
            <stop offset="100%" stopColor="rgba(40,28,12,.05)" />
          </linearGradient>
        </defs>
        {Array.from({ length: 9 }).map((_, i) => (
          <path key={i} d={`M -100 ${40 + i * 8} C 200 ${10 + i * 12}, 600 ${70 + i * 6}, 1400 ${30 + i * 10}`} fill="none" stroke="url(#topo)" strokeWidth={1} opacity={0.3} />
        ))}
      </svg>
    </div>
  );
}

function TitleBadge() {
  return (
    <div className="select-none inline-flex items-center gap-2 rounded-2xl border border-stone-700/20 bg-stone-100/80 backdrop-blur px-3 py-2 shadow">
      <Wand2 className="w-4 h-4 text-stone-700" />
      <div>
        <div className="text-xs uppercase tracking-widest text-stone-600">AO Hackathon Demo</div>
        <div className="text-sm font-semibold text-stone-800">Map of the Soul — Art Genome (UI)</div>
      </div>
    </div>
  );
}

function ClusterLabel({ cluster }: { cluster: (typeof CLUSTERS)[number] }) {
  const { x, y } = cluster.center;
  return (
    <div className="absolute" style={{ left: `${x}%`, top: `${y}%`, transform: "translate(-50%, -50%)" }}>
      <div className="rounded-full border border-stone-700/10 bg-stone-50/70 backdrop-blur px-3 py-1 text-xs shadow-sm">
        <span className="font-semibold" style={{ color: `hsl(${cluster.hue} 35% 28%)` }}>{cluster.label}</span>
        <span className="ml-2 text-stone-600">{cluster.lore}</span>
      </div>
    </div>
  );
}

function GenomeNode({ node, onSelect, selected }: { node: NodeT; onSelect: () => void; selected: boolean }) {
  const cluster = clusterOf(node.clusterId);
  const base = `hsl(${cluster.hue} 35% 28%)`;
  const ring = `hsl(${cluster.hue} 60% 60%)`;

  return (
    <div className="absolute" style={{ left: `${node.x}%`, top: `${node.y}%`, transform: "translate(-50%, -50%)" }}>
      <div className="group relative">
        <motion.button
          whileHover={{ y: -2 }}
          whileTap={{ scale: 0.98 }}
          onClick={onSelect}
          className={`relative isolate grid place-items-center w-10 h-10 md:w-11 md:h-11 rounded-full shadow-lg border ${selected ? "ring-2 ring-black" : ""}`}
          style={{ background: `radial-gradient(circle at 35% 30%, ${ring}, ${base})`, borderColor: ring }}
        >
          <span className="sr-only">Open info for {node.title}</span>
          <div className="pointer-events-none absolute -z-10 inset-[-10px] rounded-full opacity-0 group-hover:opacity-70 transition" style={{ boxShadow: `0 0 30px ${ring}` }} />
        </motion.button>
        {/* label tooltip */}
        <div className="absolute left-7 top-1/2 -translate-y-1/2 translate-x-2 opacity-0 group-hover:opacity-100 transition pointer-events-none">
          <div className="rounded-xl border border-stone-700/20 bg-stone-50/95 backdrop-blur px-3 py-1.5 text-xs shadow">
            <div className="font-semibold">{node.title}</div>
            <div className="text-stone-600">{node.type} • {cluster.label}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function EdgeOverlay({ nodes, edges, selectedId }: { nodes: NodeT[]; edges: Edge[]; selectedId: number | null }) {
  const nodeMap = useMemo(() => Object.fromEntries(nodes.map((n) => [n.id, n])), [nodes]);

  return (
    <svg className="absolute inset-0 w-full h-full pointer-events-none" aria-hidden>
      {edges.map((edge) => {
        const a = nodeMap[edge.from];
        const b = nodeMap[edge.to];
        if (!a || !b) return null;
        const x1 = `${a.x}%`, y1 = `${a.y}%`, x2 = `${b.x}%`, y2 = `${b.y}%`;
        const strong = edge.weight >= 0.7;
        const weak = edge.weight < 0.5;
        const width = 0.8 + edge.weight * 3.2; // 0.8px -> 4px
        const alpha = selectedId == null || selectedId === edge.from || selectedId === edge.to ? 0.65 : 0.18;
        const dash = weak ? "4 4" : strong ? "0" : "2 3";
        return (
          <line
            key={edge.id}
            x1={x1}
            y1={y1}
            x2={x2}
            y2={y2}
            stroke={`rgba(57,45,28,${alpha})`}
            strokeWidth={width}
            strokeLinecap="round"
            strokeDasharray={dash}
          />
        );
      })}
    </svg>
  );
}

function InfoCard({ node, edges, nodeById, onClose }: { node: NodeT; edges: Edge[]; nodeById: Record<number, NodeT>; onClose: () => void }) {
  const cluster = clusterOf(node.clusterId);
  const neighbors = useMemo(
    () => edges.filter((e) => e.from === node.id || e.to === node.id).sort((a, b) => b.weight - a.weight),
    [edges, node.id]
  );

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 10 }} className="fixed right-4 bottom-4 z-40 max-w-sm">
      <div className="rounded-3xl border border-stone-700/20 bg-stone-50/95 backdrop-blur shadow-2xl overflow-hidden">
        <div className="flex items-center justify-between gap-2 px-4 py-3 border-b border-stone-700/10">
          <div>
            <div className="text-xs uppercase tracking-widest text-stone-600">{cluster.label}</div>
            <div className="font-semibold text-stone-900">{node.title}</div>
          </div>
          <button onClick={onClose} className="rounded-full p-2 hover:bg-stone-200/70 transition" aria-label="Close">
            <Info className="w-4 h-4 text-stone-700" />
          </button>
        </div>
        <div className="px-4 py-3 space-y-3">
          <div className="text-[13px] text-stone-700">
            Tags: {node.tags.map((t, i) => (
              <span key={t + i} className="inline-block rounded-full border border-stone-700/20 bg-stone-100 px-2 py-[2px] mr-1">{t}</span>
            ))}
          </div>
          <div className="rounded-2xl border border-stone-700/10 bg-white/80 p-3">
            <div className="text-xs uppercase tracking-widest text-stone-500 mb-2">Agent conversation excerpts</div>
            <div className="space-y-2 max-h-32 overflow-auto pr-1">
              {node.whispers.map(([speaker, line], idx) => (
                <div key={idx} className="text-[13px] leading-snug"><span className="font-semibold text-stone-800">{speaker}:</span> <span className="text-stone-700">{line}</span></div>
              ))}
            </div>
          </div>

          <div className="rounded-2xl border border-stone-700/10 bg-white/80 p-3">
            <div className="text-xs uppercase tracking-widest text-stone-500 mb-2">Connected cousins</div>
            <div className="space-y-2 max-h-40 overflow-auto pr-1">
              {neighbors.map((e) => {
                const other = nodeById[e.from === node.id ? e.to : e.from];
                if (!other) return null;
                return (
                  <div key={e.id} className="text-[13px]">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-stone-800">{other.title}</span>
                      <span className="text-stone-600">{(e.weight * 100).toFixed(0)}%</span>
                    </div>
                    <div className="h-1.5 rounded bg-stone-200 overflow-hidden">
                      <div className="h-full bg-stone-700" style={{ width: `${e.weight * 100}%` }} />
                    </div>
                    {e.note && <div className="text-[12px] text-stone-600 mt-1">{e.note}</div>}
                  </div>
                );
              })}
            </div>
          </div>

          <div className="text-[12px] text-stone-600">Hint: In the real app, this card would show provenance, symbolic affinities, and signed edge attestations.</div>
        </div>
        <div className="px-4 py-3 bg-stone-100/70 border-t border-stone-700/10 flex items-center justify-between">
          <div className="text-[12px] text-stone-700">{node.type} artifact • {cluster.label}</div>
          <button onClick={onClose} className="rounded-xl border border-stone-700/20 bg-white/80 px-3 py-1.5 text-sm shadow hover:bg-white">Close</button>
        </div>
      </div>
    </motion.div>
  );
}

function Legend() {
  return (
    <div className="absolute left-3 bottom-3 sm:left-4 sm:bottom-4">
      <div className="rounded-2xl border border-stone-700/20 bg-stone-50/85 backdrop-blur px-3 py-2 text-xs shadow max-w-[80vw]">
        <div className="uppercase tracking-widest text-stone-600 mb-1">Legend</div>
        <div className="flex flex-wrap gap-x-4 gap-y-1">
          {CLUSTERS.map((c) => (
            <div key={c.id} className="flex items-center gap-2">
              <span className="inline-block w-3 h-3 rounded-full" style={{ background: `hsl(${c.hue} 60% 50%)` }} />
              <span className="text-stone-800">{c.label}</span>
            </div>
          ))}
          <div className="flex items-center gap-2">
            <span className="inline-block w-6 h-[3px] bg-stone-800 rounded" />
            <span className="text-stone-800">thicker = stronger kinship</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="inline-block w-6 h-[3px] bg-stone-800 rounded" style={{ outline: "1px dashed rgba(0,0,0,.6)", outlineOffset: -3 }} />
            <span className="text-stone-800">dashed = tenuous kinship</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function AddArtModal({ onClose, onSpawn }: { onClose: () => void; onSpawn: (n: NodeT) => void }) {
  const [title, setTitle] = useState("");
  const [mode, setMode] = useState<"image" | "text">("image");
  const [clusterId, setClusterId] = useState(CLUSTERS[1].id);

  function spawn() {
    const baseId = Math.max(...INITIAL_NODES.map((n) => n.id), 9);
    const id = baseId + Math.floor(Math.random() * 1000) + 1;
    const c = CLUSTERS.find((cc) => cc.id === clusterId)!;
    const jitter = () => Math.random() * 10 - 5;
    const x = Math.max(6, Math.min(94, c.center.x + jitter()));
    const y = Math.max(6, Math.min(94, c.center.y + jitter()));

    const newNode = n(
      id,
      title || (mode === "image" ? "Untitled Image" : "Untitled Text"),
      mode,
      clusterId,
      x,
      y,
      [
        ["New Artifact", "Hello. I am looking for my family."],
        [c.label, "We share a tone — come closer."],
      ]
    );

    onSpawn(newNode);
    onClose();
  }

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-50 grid place-items-center p-4 bg-black/30">
      <motion.div initial={{ y: 12, scale: 0.98, opacity: 0 }} animate={{ y: 0, scale: 1, opacity: 1 }} exit={{ y: 8, scale: 0.98, opacity: 0 }} transition={{ type: "spring", stiffness: 260, damping: 24 }} className="w-full max-w-lg rounded-3xl border border-stone-700/30 bg-stone-50 shadow-2xl overflow-hidden">
        <div className="px-5 py-4 border-b border-stone-700/10 flex items-center gap-2">
          <Upload className="w-4 h-4 text-stone-700" />
          <div>
            <div className="text-xs uppercase tracking-widest text-stone-600">Add your art</div>
            <div className="font-semibold text-stone-900">Spawn an agent on the map</div>
          </div>
        </div>
        <div className="p-5 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <button onClick={() => setMode("image")} className={`rounded-2xl border px-3 py-2 text-sm shadow-sm ${mode === "image" ? "bg-white border-stone-700/40" : "bg-stone-100/70 border-stone-600/20 hover:bg-white"}`}>Image</button>
            <button onClick={() => setMode("text")} className={`rounded-2xl border px-3 py-2 text-sm shadow-sm ${mode === "text" ? "bg-white border-stone-700/40" : "bg-stone-100/70 border-stone-600/20 hover:bg-white"}`}>Text</button>
          </div>

          <div className="space-y-2">
            <label className="text-sm text-stone-700">Title</label>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={mode === "image" ? "eg. Lumen Diagram" : "eg. Diary: 14th Night"} className="w-full rounded-xl border border-stone-600/30 bg-white px-3 py-2 shadow-inner outline-none focus:ring-2 focus:ring-stone-400/40" />
          </div>

          <div className="space-y-2">
            <label className="text-sm text-stone-700">Choose a home cluster</label>
            <div className="grid grid-cols-3 gap-2">
              {CLUSTERS.map((c) => (
                <button key={c.id} onClick={() => setClusterId(c.id)} className={`rounded-2xl border px-3 py-2 text-sm text-left shadow-sm ${clusterId === c.id ? "bg-white border-stone-700/40" : "bg-stone-100/70 border-stone-600/20 hover:bg-white"}`}>
                  <div className="flex items-center gap-2">
                    <span className="inline-block w-2.5 h-2.5 rounded-full" style={{ background: `hsl(${c.hue} 60% 50%)` }} />
                    <span className="font-medium text-stone-800">{c.label}</span>
                  </div>
                  <div className="text-[11px] text-stone-600 mt-1">{c.lore}</div>
                </button>
              ))}
            </div>
          </div>
        </div>
        <div className="px-5 py-4 bg-stone-100/70 border-t border-stone-700/10 flex items-center justify-end gap-2">
          <button onClick={onClose} className="rounded-xl border border-stone-600/20 bg-white/80 px-3 py-2 text-sm">Cancel</button>
          <button onClick={spawn} className="rounded-xl border border-stone-700/40 bg-black text-white px-4 py-2 text-sm shadow">Spawn to map</button>
        </div>
      </motion.div>
    </motion.div>
  );
}

function CompassSVG({ size = 320 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 200 200" fill="none">
      <g opacity="0.9" stroke="#2b2011">
        <circle cx="100" cy="100" r="92" strokeWidth="1.2" fill="transparent" />
        <circle cx="100" cy="100" r="70" strokeWidth="0.8" />
        <circle cx="100" cy="100" r="45" strokeWidth="0.8" />
        <g strokeWidth="0.6">
          {Array.from({ length: 32 }).map((_, i) => {
            const a = (i / 32) * Math.PI * 2;
            const x1 = 100 + Math.cos(a) * 70;
            const y1 = 100 + Math.sin(a) * 70;
            const x2 = 100 + Math.cos(a) * 92;
            const y2 = 100 + Math.sin(a) * 92;
            return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} />;
          })}
        </g>
        <polygon points="100,14 112,100 100,186 88,100" fill="#2b2011" />
        <circle cx="100" cy="100" r="5" fill="#2b2011" />
      </g>
    </svg>
  );
}

// icons (inline so we can tweak stroke width subtly)
function SearchIcon() {
  return (
    <svg className="w-4 h-4 text-stone-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <circle cx="11" cy="11" r="7" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

// small utilities -----------------------------------------------------------
function dist(a: { x: number; y: number }, b: { x: number; y: number }) {
  const dx = a.x - b.x; const dy = a.y - b.y; return Math.hypot(dx, dy);
}
