# AGENTS.md

## Project Overview
- Project name: `打工养猫日记`
- Type: static single-player web game
- Stack: plain `HTML + CSS + JavaScript`
- Runtime target: direct local open via `file://`
- Storage: browser `localStorage`
- Main save key: `catGameSaveV1`

## Core Constraints
- Do not add a backend, database, login, or cloud save.
- Keep the project runnable by opening `index.html` directly.
- Do not replace the ordered `<script>` loading model with bundlers or ESM imports unless the project direction explicitly changes.
- Prefer extending existing modules instead of creating scattered one-off scripts.
- Keep data naming aligned with existing conventions: `player`, `cats`, `inventory`, `jobs`, `tasks`, `home`, `settings`.

## Architecture Rules
- `src/js/core`: global namespace and i18n
- `src/js/data`: static game content tables
- `src/js/state`: save creation, normalization, persistence
- `src/js/systems`: gameplay logic and realtime syncing
- `src/js/ui`: page renderers only
- `src/js/utils`: generic helpers
- `src/styles`: reset, layout, theme styles

## Implementation Rules
- Preserve compatibility with old saves when adding new fields.
- New runtime save fields should be normalized in `src/js/state/gameState.js`.
- Realtime progression should be handled through sync systems, not frame-based assumptions.
- UI renderers should stay mostly declarative and avoid owning gameplay logic.
- Prefer existing i18n helpers for user-facing text. Avoid hardcoded Chinese or English in renderers when a translation key is appropriate.
- Keep desktop and mobile compatibility in mind.
- Keep touch interactions compatible with pointer events where practical.

## Save/Data Rules
- New top-level save fields belong in the existing save object, not separate keys.
- Save migrations should be non-destructive.
- Do not remove or rename established save fields casually.
- If a feature creates generated cats or furniture layout state, ensure reload/import paths preserve them.

## Development Workflow
- 每次对本仓库的网页版或原生 iOS 进行开发、修复、重构、代码审查或依赖调整时，都加载并应用 `$ponytail`，默认使用 `full` 模式；用户明确指定其它模式或停用时，以用户要求为准。技能说明位于 `$CODEX_HOME/skills/ponytail/SKILL.md`，未设置 `CODEX_HOME` 时使用 `~/.codex/skills/ponytail/SKILL.md`。
- Ponytail 的检查范围覆盖当前任务及相关调用方、边界和必要验证；保留现有架构、存档兼容、可访问性、QA 与 iOS 发布规则。配套 review/audit/debt/gain/help 技能按任务需要使用，不默认触发全仓审计或无关重构。

## QA Rules
- Minimum check after JS edits: run `node --check` across `src/js`.
- If only documentation changes, no gameplay verification is required.
- When reporting status, separate:
  - finished
  - partially finished
  - broken
  - next work

## Current Known Product Direction
- The game has already moved beyond MVP.
- Active systems include:
  - realtime work
  - cat care and decay
  - disease and hospital
  - shop and furniture
  - room scene
  - collection and breeding
  - arcade slot machine
  - save import/export
  - bilingual UI
- Near-term work should prioritize stabilization, consistency, and finishing incomplete systems over adding unrelated new modules.
