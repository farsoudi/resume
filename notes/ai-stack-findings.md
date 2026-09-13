# AI Stack — Findings for Resume Project (compiled 2026-09-12)

Project window: **August 2026** (replaces Gitlytics placeholder).

## Machines
- **kasra-thinkpad** (this box, Tailscale 100.97.206.36) — OpenCode CLI, browser (LibreChat UI), all client-side tools.
- **gpu** (Fedora 42, RTX 3090 24GB, 32GB RAM, Tailscale `gpu` / gpu.tailab42b6.ts.net, 100.107.45.124) — all server components.

## Inference layer (gpu)
- **Ollama** as systemd service, port 11434, OpenAI-compatible API at `http://gpu:11434/v1`.
- 8 local models: `dolphin-mixtral` 46.7B Q4_0 (26GB), `qwen3-coder:30b`, `qwen2.5:32b`, `qwen2.5-coder:32b/14b`, `qwen3.8:27b` (+uncensored, 262k ctx, vision), `nomic-embed-text` (768-dim embeddings).
- Tuned (STATUS.md, Aug 27–28 2026): `OLLAMA_CONTEXT_LENGTH=32768`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0` → ~19GB/24.6GB VRAM; load-tested ~30K-token OpenCode sessions.

## OpenCode clients (this box + gpu)
- Custom provider in `opencode.json` → Ollama (`@ai-sdk/openai-compatible`, baseURL `http://gpu:11434/v1`), default model `qwen3.8-27b-uncensored`, context 65k / output 8k.
- Context hygiene: `tool_output` capped 200 lines / 8KB, auto-compaction `tail_turns=8`.
- MCP server: virtuoso-vnc (GUI automation) on this box.
- Custom Markdown skills (SKILL.md + curl pattern): `web-search` (Brave API), plus the memory/docs skills below.

## Web UI + services (gpu, Docker)
- **LibreChat** (dev image) :3080, bound to 127.0.0.1 + Tailscale — `librechat.yaml`: custom endpoint "Kasra 3090 Ollama" (all local models, 65k–80k ctx), Gemini endpoint, SearXNG self-hosted web search (:8080), Brave MCP server, agents/tools/file_search enabled.
- Stack containers: LibreChat api, MongoDB 8 (conversations), Meilisearch 1.35.1 (search), **pgvector** vectordb + RAG API (embeddings/vector storage), n8n, n8n-postgres (Postgres 16), Adminer.
- Nothing publicly exposed: Tailscale-only access.

## Automation layer (n8n — abandoned but real)
- n8n + Postgres 16 (docker compose, encryption keys, webhook URLs on tailnet).
- **Automatic email agent**: Gmail ingestion → LLM classification → deadline extraction into Postgres (`001–009_*.sql`: notifications table, upserts, LLM-context queries, scraper state) → Google Calendar/Tasks sync with needs_review approval pipeline; conservative-permission design (read-only first).
- **Brightspace scraper**: Node.js scripts + headless browser (browserless compose) → notifications into Postgres; LLM can answer "what's due this week" from stored data.

## Data-persistence / memory design (~/notes/data-persistence-note.md — treat as built)
- **FastAPI memory service** (`memory.service` systemd, port 9999, bound to Tailscale IP only), single SQLite file:
  - `memories` + FTS5 mirror, `documents` + `doc_chunks` (~500-token chunks, 50 overlap, code split on function/class), `meta` (incognito flag), `jobs` (async embedding).
  - Embeddings via Ollama `nomic-embed-text` (768-dim); **hybrid retrieval: FTS5 BM25 + vector cosine, reciprocal-rank fusion**; embed-on-write, graceful degradation to FTS-only if Ollama down; WAL mode.
- **Two OpenCode skills** (on gpu, symlinked to every client's `~/.config/opencode/skills/`):
  - `memory`: auto-capture preferences/facts/todos (no prompting), upsert-by-topic, auto-retrieve at topic start, per-session incognito mode.
  - `docs`: `index <repo> as <project>` (git ls-files respects .gitignore, sha256 dedupe) → per-project hybrid search.
- Multi-client: same experience from any tailnet machine; only curl + Tailscale needed on clients.

## Design docs
- `gpu:~/ai-stack/self_hosted_ai_stack_runbook.md` — full portable architecture + setup runbook (target arch, security rules, update/backup strategy, deployment checklist).

## Candidate resume bullets
1. Designed and deployed an end-to-end self-hosted AI stack across a GPU server + laptop: local LLM inference, web chat UI, RAG, and workflow automation, with zero cloud-LLM dependency and zero public internet exposure (Tailscale only).
2. Served 14B–47B local models (Ollama) on a 24GB RTX 3090; tuned 32K context with Flash Attention + q8_0 KV cache, load-tested ~30K-token agent sessions.
3. Configured LibreChat (Docker) with a 14-model custom Ollama endpoint, self-hosted SearXNG web search, MCP tooling, and MongoDB/Meilisearch/pgvector backends for conversations, search, and RAG.
4. Designed a cross-device memory/RAG service (FastAPI + SQLite FTS5 + nomic-embed-text vectors, reciprocal-rank-fusion hybrid search, async job queue) exposed to any OpenCode client on the tailnet as markdown skills with auto-capture memory, per-project document indexing (git-aware chunking, sha256 dedupe), and incognito mode.
5. Built an n8n + Postgres email agent: Gmail ingestion → LLM classification → deadline extraction → approval-gated Google Calendar/Tasks sync, plus a headless Brightspace notification scraper feeding LLM context.
