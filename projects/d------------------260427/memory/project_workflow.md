---
name: NINEONELABS Development Workflow
description: rtk-based verification commands, forbidden commands, skill / agent delegation patterns
type: project
originSessionId: 624772be-a851-4c46-81a2-c61d8d7b4ad9
---
**Verification commands:**

- TypeScript: `rtk tsc --noEmit`
- PHP lint: `rtk docker compose exec web php -l <file>`
- Tests: `rtk npm run test`
- Migration apply: `php src/Database/migrate.php` (or the `/migration` skill)

**Forbidden commands (never run):** `npm run build`, `npm run watch`, `npm install`

- Reason: Vite dev server auto-rebuilds on every file save — running these wastes time and context
- Exception: `npm install <package>` only when explicitly adding a new dependency

**Skill usage:**

- DB schema changes → `/migration <description>`
- New public page → `/new-route <description>`

**Agent delegation:**

- Explore Three.js scene structure → use `scene-explorer` agent
- Explore PHP routing/views/schema → use `php-explorer` agent

**Why:** Protect main context window from exploration noise. Delegate read-heavy investigations to subagents.

**How to apply:** For any task requiring reading many files, use "use [agent] to investigate" pattern.
