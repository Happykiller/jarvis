# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Is Jarvis?

Jarvis is a **Windows automation launcher** (PowerShell + VBS) that bootstraps the entire **DraftDream** development environment. It runs as a system tray application and automates the complex setup of a multi-service fitness coaching SaaS platform running in WSL2.

The actual product codebase lives in WSL2 at `/home/admin/DraftDream`.

## Jarvis Files

| File | Purpose |
|------|---------|
| `jarvis-tray.ps1` | System tray app with context menu (main entry point) |
| `jarvis-tray.vbs` | VBS wrapper for hidden (no console) execution |
| `dev-setup.ps1` | Orchestration script: opens 7 terminal tabs, waits for ports, launches Chrome |
| `dev-setup.bat` | Batch wrapper for PowerShell execution policy bypass |
| `jarvis.ico` | System tray icon |

## What dev-setup.ps1 Does

1. Detects screen dimensions
2. Launches Windows Terminal with 7 tabs: LazyGit, Claude, api, backoffice, frontoffice, showcase, sandbox
3. Launches Antigravity (code editor)
4. Monitors ports 5173/5174/5175 until ready
5. Launches Chrome with 3 tabs pointing at dev servers + opens DevTools

## DraftDream Platform (the managed project)

**Location**: `/home/admin/DraftDream` (WSL2)  
**Version**: 0.19.0 | **Repo**: github.com/Happykiller/DraftDream

### Stack
- **API**: NestJS 11 + Fastify + Mercurius (GraphQL) + MongoDB 7 — hexagonal architecture with Inversify DI
- **Frontoffice / Backoffice / Showcase**: React 19 + Vite 8 + TypeScript 5.9.3 + Material UI 7 + Zustand + TanStack Query + i18next (EN/FR)
- **Infrastructure**: Docker Compose + Nginx reverse proxy (7 domains)

### Development Commands

```bash
# Start dev DB
docker compose -f docker-compose.dev.yml up -d

# API (NestJS) — run from /home/admin/DraftDream/api/
npm run start:dev        # watch mode
npm run test             # Jest
npm run test:coverage
npm run lint             # ESLint
npm run lint:fix
npm run db:fresh         # full reset + seed

# Frontend apps (frontoffice / backoffice / showcase)
npm run dev              # Vite dev server
npm run build            # type-check + build
npm run test             # Vitest
npm run lint

# Root build targets (from /home/admin/DraftDream/)
make build               # build all Docker images in parallel
make api                 # build & save api image
make frontoffice / backoffice / showcase / mobile
```

### Architecture Principles

**API — Hexagonal (Ports & Adapters)**  
Business logic lives in usecases; MongoDB adapters and GraphQL resolvers are driving/driven adapters. Never let framework concerns bleed into usecases.

**Frontend — Layered**  
GraphQL fetch service → TanStack Query hooks → Zustand stores (session, loader, flash) → Custom domain hooks → Pure rendering components. All async operations must use the `useAsyncTask` hook for global loader sync.

**REGEX source of truth**: `api/src/common/REGEX.ts` — frontend validation regexes must match this file exactly.

**i18n parity**: EN and FR translation keys must stay synchronized in all three frontend apps.

### Cross-Stack Rules (from AGENTS.md)
- All files must be committed unless in `.gitignore` — no untracked files
- English-only code comments; no commented-out code
- Staircase import formatting: external libs grouped separately from internal modules
- JSX templates require `{/* General information */}` section markers

### Service Endpoints

| Service | Dev | Production |
|---------|-----|-----------|
| API (GraphQL) | `http://localhost:3000/graphql` | `api.fitdesk.happykiller.net` |
| Frontoffice | `http://localhost:5173` | `fo.fitdesk.happykiller.net` |
| Backoffice | `http://localhost:5174` | `bo.fitdesk.happykiller.net` |
| Showcase | `http://localhost:5175` | `showcase.fitdesk.happykiller.net` |

### MCP Servers (`.mcp.json`)
MongoDB, Playwright, Docker, and Fetch MCP servers are configured for agent use against the local dev environment.

### Environment
Copy `.env.example` → `.env` (never commit `.env`). Key variables: `API_PORT`, `DB_CONN_STRING`, `VITE_GRAPHQL_ENDPOINT`, `MORGANS_ENDPOINT` (email service).
