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
    mode = "float", -- or "virtual": description as virtual lines above the step
    width = 72,
    keys = { next = "]n", prev = "[n", stop = "<leader>tq" },
  },
}
```

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
