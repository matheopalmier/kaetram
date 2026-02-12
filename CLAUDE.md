# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kaetram (rebranded as Shefira) is an open-source 2D MMORPG engine built with TypeScript. It's a complete rewrite of BrowserQuest with a modern stack. The codebase is a Yarn v4 monorepo using workspaces.

## Commands

```bash
# Install dependencies (requires Corepack for Yarn v4)
corepack enable && yarn install

# Development (starts all packages concurrently: Vite client on :9000, server on :9001)
yarn dev

# Build all packages
yarn build

# Lint (ESLint for .ts, Stylelint for .scss)
yarn lint
yarn lint:fix

# E2E tests (requires running dev server + MongoDB)
yarn test:run          # Headless Cypress
yarn test:open         # Interactive Cypress UI

# Export tilemap data
yarn map

# Run individual packages
yarn packages dev      # All packages in dev mode
yarn hub               # Hub server in watch mode
```

## Monorepo Structure

```
packages/
├── client/    - Browser game client (Vite + Canvas/WebGL)
├── server/    - Game server (Node.js + uWebSockets.js)
├── hub/       - Cross-server gateway for multi-server clusters
├── common/    - Shared types, network protocol, config, database abstractions
├── tools/     - Map parser, bot utilities
└── e2e/       - Cypress + Cucumber BDD tests
```

All packages use `@kaetram/*` namespace. Path alias `@kaetram/*` maps to `packages/*` via tsconfig.

## Architecture

### Client (`@kaetram/client`)
- **Entry**: `src/main.ts` → `App` (UI/login) → `Game` (core orchestrator)
- **Rendering**: Dual renderer — WebGL (primary) and Canvas 2D (fallback), with GLSL shaders
- **Controllers**: Audio, Input, Entities, Menu, Bubble, Chat, Zoning
- **Entity hierarchy**: Entity → Character → Player/Mob/NPC
- **Networking**: Socket.io-client connecting to server WebSocket
- **Pathfinding**: Client-side A* for responsive movement
- **Build**: Vite with PWA, legacy browser support, GLSL plugins; dev port 9000

### Server (`@kaetram/server`)
- **Entry**: `src/main.ts` → creates `World` instance
- **World**: Core game state — manages entities, combat, quests, skills, guilds, trading
- **Networking**: uWebSockets.js (uWS v20) on port 9001; packets batched every 300ms (`UPDATE_TIME`)
- **Map**: Region/chunk-based system for bandwidth-efficient broadcasting
- **Database**: MongoDB (optional — `SKIP_DATABASE=true` runs without it)
- **Runtime**: tsx for TypeScript execution and watch mode

### Hub (`@kaetram/hub`)
- Gateway that connects multiple game servers for horizontal scaling
- Forwards player connections to least-loaded server
- REST API on port 9526, WebSocket on port 9527

### Common (`@kaetram/common`)
- Shared TypeScript types (`types/` dir with 30+ `.d.ts` files)
- Network protocol: packet definitions in `network/`
- Config loader, MongoDB abstractions, Discord integration, localization (EN/FR)
- **Not compiled** — consumed as raw TypeScript by other packages

### Networking Protocol
- Packet-based communication: client ↔ server via Socket.io/uWS
- Server batches outgoing packets on 300ms intervals
- Region system divides the map into chunks; only relevant data is broadcast to nearby players

## Configuration

Environment config via `.env` files (template: `.env.defaults`):
- `.env` for local overrides, `.env.{NODE_ENV}` for environment-specific
- Key settings: `SKIP_DATABASE`, `HOST`/`PORT`, `HUB_ENABLED`, `OVERWRITE_AUTH`, `MAX_PLAYERS`

## Deployment

Target: OVH VPS (IP: 51.178.42.132), Ubuntu 22.04.5 LTS, Node.js v20.x. Domain: shefira.com.
All deploy scripts are in `deploy/`. Full admin doc in `DOCS_SHEFIRA.md`.

```bash
# First-time full deploy (provision + sync + build + start)
bash deploy/deploy.sh

# Update only (sync code + rebuild + restart services)
bash deploy/update.sh

# PM2 commands (on the VPS, from project root for Yarn workspaces)
pm2 restart all          # Restart server + hub
pm2 logs                 # View logs
pm2 monit                # Monitor processes
```

- **VPS setup** (`deploy/setup_vps.sh`): installs Node 20, Yarn (Corepack), PM2, MongoDB 7.0, Nginx, UFW firewall
- **Process manager**: PM2 via `deploy/ecosystem.config.cjs` — runs `kaetram-server` and `kaetram-hub`. Must be launched from project root for Yarn workspaces to resolve.
- **Reverse proxy**: Nginx config at `/etc/nginx/sites-available/kaetram` on VPS. HTTP→HTTPS redirect, SSL via Let's Encrypt. Routes:
  - `/` → static client files (`packages/client/dist/`)
  - `/ws` → `:9001` (game WebSocket, upgrade to WSS)
  - `/server`, `/all` → `:9526` (hub API)
- **Secrets**: `deploy/.env.deploy` stores `SSHPASS` for sshpass-based SSH; `.env` on remote for runtime config
- **Production .env**: `SSL=true` (enables `wss://`/`https://` in client build), `HOST=shefira.com`
- **uWS.js constraint**: v20.25.0 requires GLIBC 2.35+ (Ubuntu 22.x) and Node 20+. Do not downgrade without checking binary compatibility.
- **Ports**: 80/443 (Nginx HTTP/HTTPS), 9001 (WebSocket server), 9526 (Hub API)

## Code Style

- **TypeScript**: Strict mode, ESNext target, `noImplicitAny`, `strictNullChecks`
- **Prettier**: 100 char width, 4-space indent, single quotes, no trailing commas
- **ESLint**: TypeScript strict + Unicorn + Import ordering + Prettier integration
- **Prefer `let`** over `const` (enforced by eslint-plugin-prefer-let)
- **Commits**: Conventional commits with types: `add`, `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `remove`, `revert`, `style`, `test`
- **Git flow**: `develop` is the main development branch, `master` is production
