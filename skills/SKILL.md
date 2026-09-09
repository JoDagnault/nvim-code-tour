---
name: code-tour
description: Write a CodeTour `.tour` file that walks a reader through a change you just implemented, for playback in nvim-code-tour or VS Code CodeTour. Use only when asked for a code tour, or via /code-tour. Do not write tours on your own.
---

# Code tour of what was implemented

A tour is a short, ordered walk through the change you just made. The reader
plays it in their editor: each step opens a file, spotlights a line or a span,
and shows your explanation. It is a throwaway aid to understanding, not
documentation, so optimise for a fast mental model rather than completeness.

## Output

Write `.tours/<slug>.tour` at the project root, where `<slug>` is a short
kebab-case name for the change (for example `csv-export.tour`). Create the
`.tours/` directory if needed. Overwrite an existing tour with the same name.

## Format

Plain JSON. The player reads exactly these fields and ignores everything else:

```json
{
  "$schema": "https://aka.ms/codetour-schema",
  "title": "Add CSV export to the reports page",
  "steps": [
    {
      "description": "### Why\n\nOne content step with no file is fine as an intro: what the change is and why."
    },
    {
      "file": "src/reports/ReportsPage.tsx",
      "line": 34,
      "description": "### Entry point\n\nThe new button. It passes the *filtered* rows, not the full dataset."
    },
    {
      "file": "src/reports/csvExport.ts",
      "selection": { "start": { "line": 12, "character": 1 }, "end": { "line": 31, "character": 2 } },
      "description": "### Core logic\n\nA `selection` spotlights a span instead of one line. Use it for a whole function."
    }
  ]
}
```

- `title` and `steps` are required. Each step requires `description` (markdown).
- `file` is relative to the project root. `line` and all `selection` fields are
  1-based. `character` is a column; `end` is exclusive.
- A step with no `file` is a content step: prose only, shown centered. Use one
  for the intro or the closing trade-offs, not in the middle.
- Start each description with a short `###` heading. The player shows it as the
  step title.
- Not supported: `pattern`, `directory`, `uri`, `commands`, `view`. Do not use them.

## Curation

- **5 to 10 steps.** More means you are narrating the diff, not curating a tour.
- **Order by narrative**: entry point, then core logic, then edge cases and
  trade-offs. Never by file-tree order or the order you wrote the code in.
- **Explain decisions, not edits.** "Why this and not the obvious alternative"
  earns a step. "Renamed a variable" does not. A reviewer already has `git diff`.
- **Spotlight the interesting line**, not line 1 of the file. Use `selection`
  when the unit of interest is a block.
- Keep each description to a heading and one to four sentences.

## The hard rule: never guess a line number

A stale or invented line number is the one failure that makes a tour worse than
nothing. Right before emitting each step, re-read the file and take the line
number from what you see now, not from memory of when you wrote it. Edits made
after you wrote a section shift every line below it.

## Validate before reporting done

For every step with a `file`:

1. The file exists at that path, relative to the project root.
2. `line`, or `selection.end.line`, is not greater than the file's line count
   (`wc -l` is enough).
3. The spotlighted line actually contains what the description talks about.
   Print it and look.

Fix any failure, then tell the user the tour path and how to play it:
`:CodeTour` in Neovim from the project root, or the CodeTour extension in VS Code.
