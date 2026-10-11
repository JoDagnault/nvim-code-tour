# nvim-code-tour

Minimal player for [CodeTour](https://github.com/microsoft/codetour) `.tour` files.
Opens each step's file, dims everything except the step's line or selection, and shows
the description. Next, prev, stop. Nothing else.

Requires Neovim 0.10+. No dependencies.

## Install (lazy.nvim)

```lua
{
  dir = "~/Projects/nvim-code-tour",
  cmd = { "CodeTour", "CodeTourNext", "CodeTourPrev", "CodeTourStop" },
  opts = {
    mode = "float", -- or "split": pane on the right; "virtual": lines above the step
    width = 72, -- float and virtual text width
    pane_width = 50, -- split mode
    keys = { next = "]n", prev = "[n", stop = "<leader>tq" },
  },
}
```

In `split` mode the description never covers the code: it lives in a pane on the right
that stays open for the whole tour. `<C-w>l` into it to scroll a long description; `]n`
and `[n` work from there too. The pane closes when the tour stops.

Keys are mapped when a tour starts and removed when it stops. `]n` / `[n` are unused by Neovim and LazyVim.

## Use

- `:CodeTour` picks from `.tours/**/*.tour` under the cwd, or `:CodeTour path/to/x.tour`.
- `:CodeTourNext` / `:CodeTourPrev` / `:CodeTourStop`.

Highlight groups: `CodeTourDim`, `CodeTourStep`, `CodeTourTitle`, `CodeTourText`.

## Format

A `.tour` is JSON: `title`, `steps[]`. Each step has a markdown `description` and
optionally `file` (relative to the directory containing `.tours/`), `line` (1-based) or
`selection` (`start`/`end` with 1-based `line` and `character`), and `title`. A step
without `file` is shown as a centered float. Other CodeTour fields are ignored.

## Authoring with an agent

`skills/SKILL.md` is a skill for Claude Code and Codex that tells the agent how to
write a tour of what it just implemented. Symlink the directory:

```sh
ln -s ~/Projects/nvim-code-tour/skills ~/.claude/skills/code-tour
ln -s ~/Projects/nvim-code-tour/skills ~/.codex/skills/code-tour
```

Then ask for a tour, or run `/code-tour`, after a change.
