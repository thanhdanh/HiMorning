# Project instructions

<!-- codebase-memory-mcp:start -->
For structural codebase exploration, use the installed `codebase-memory` skill.
<!-- codebase-memory-mcp:end -->

## Language and writing

Use English for identifiers, comments, commit messages and developer documentation.
Keep user-facing copy in English and Vietnamese localization resources. Use short,
natural words and a calm tone. New copy must ship in both languages.

Use `docs/DOC-TEMPLATE.md` for new technical guides. Start with purpose and current
status, explain the main flow, give runnable examples where useful, then cover
validation and next steps. Separate tested behavior from plans and unknowns.

## Workspace boundaries

Use pnpm 10.34.6, pinned in package.json, and pnpm-lock.yaml. Native projects use
SwiftPM/Xcode and, when implemented, Gradle; pnpm manages JavaScript tooling only.
Keep Apple code in apps/ios, future Android code in apps/android, server code in
backend/functions and language-neutral contracts/fixtures in shared/contracts.
Do not import server code into native clients or native APIs into domain modules.
Update shared fixtures and both relevant test runners when wire behavior changes.
