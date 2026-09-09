-- Minimal player for CodeTour `.tour` files: dim, highlight, next, prev.
local M = {}

local ns = vim.api.nvim_create_namespace("codetour")
local config = {
  mode = "float", -- "float" | "virtual"
  width = 72,
  keys = { next = "]n", prev = "[n", stop = "<leader>tq" },
}

-- Active tour state (nil when no tour is playing).
local state = nil

local function hl_defaults()
  vim.api.nvim_set_hl(0, "CodeTourDim", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CodeTourStep", { link = "Visual", default = true })
  vim.api.nvim_set_hl(0, "CodeTourTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "CodeTourText", { link = "NormalFloat", default = true })
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  hl_defaults()
end

-- ---------------------------------------------------------------- helpers

local function read_tour(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "cannot read " .. path
  end
  local ok, tour = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if not ok or type(tour) ~= "table" or type(tour.steps) ~= "table" then
    return nil, "invalid tour file " .. path
  end
  return tour
end

-- Root is the directory containing `.tours/`, else the cwd.
local function root_of(path)
  return path:match("^(.*)/%.tours/") or vim.fn.getcwd()
end

-- Returns 0-based {start_row, start_col, end_row, end_col} for the step,
-- end exclusive. Nil when the step has no location.
local function range_of(step)
  local s = step.selection
  if s and s.start and s["end"] then
    return s.start.line - 1, s.start.character - 1, s["end"].line - 1, s["end"].character - 1
  end
  local line = step.line or 1
  return line - 1, 0, line, 0
end

local function step_title(step, i, n)
  local title = step.title or (step.description or ""):match("^#+%s*(.-)\n") or ""
  return string.format(" Step %d/%d %s ", i, n, title)
end

local function clear_decorations()
  for buf in pairs(state.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

local function mark(buf, opts)
  vim.api.nvim_buf_set_extmark(buf, ns, opts.row, opts.col, {
    end_row = opts.end_row,
    end_col = opts.end_col,
    hl_group = opts.hl,
    hl_eol = true,
    priority = 200, -- above treesitter (100) so the dim actually wins
    strict = false,
  })
end

local function spotlight(buf, sr, sc, er, ec)
  local last = vim.api.nvim_buf_line_count(buf)
  mark(buf, { row = 0, col = 0, end_row = sr, end_col = sc, hl = "CodeTourDim" })
  mark(buf, { row = sr, col = sc, end_row = er, end_col = ec, hl = "CodeTourStep" })
  mark(buf, { row = er, col = ec, end_row = last, end_col = 0, hl = "CodeTourDim" })
end

local function description_lines(step)
  return vim.split(step.description or "", "\n", { plain = true })
end

-- Opens the description in a non-focusable float. With `code_win`, the float
-- is pinned to the bottom of that window so it never covers the spotlight;
-- without it (content steps) it is centered on the editor. Returns the float's
-- total height including borders.
local function show_float(step, title, code_win)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, description_lines(step))
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"

  local width = math.min(config.width, vim.o.columns - 4)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = title,
    focusable = false,
  })
  vim.wo[win].wrap = true
  -- Measure the real rendered height (wrap, linebreak, conceal all apply).
  local max_h = math.floor((code_win and vim.api.nvim_win_get_height(code_win) or vim.o.lines) / 2)
  local height = math.min(vim.api.nvim_win_text_height(win, {}).all, max_h)

  local cfg = { width = width, height = height }
  if code_win then
    cfg.relative = "win"
    cfg.win = code_win
    cfg.row = vim.api.nvim_win_get_height(code_win) - height - 2 -- 2 = borders
    cfg.col = math.max(0, math.floor((vim.api.nvim_win_get_width(code_win) - width) / 2))
  else
    cfg.relative = "editor"
    cfg.row = math.floor((vim.o.lines - height) / 2)
    cfg.col = math.floor((vim.o.columns - width) / 2)
  end
  vim.api.nvim_win_set_config(win, cfg)
  state.win = win
  return height + 2
end

local function show_virtual(buf, row, step, title)
  local width = math.min(config.width, vim.o.columns - 8)
  local virt = { { { title, "CodeTourTitle" } } }
  for _, l in ipairs(description_lines(step)) do
    -- naive word wrap
    local cur = ""
    for word in l:gmatch("%S+") do
      if cur ~= "" and vim.fn.strdisplaywidth(cur .. " " .. word) > width then
        table.insert(virt, { { cur, "CodeTourText" } })
        cur = word
      else
        cur = cur == "" and word or cur .. " " .. word
      end
    end
    table.insert(virt, { { cur, "CodeTourText" } })
  end
  vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { virt_lines = virt, virt_lines_above = true })
end

-- ---------------------------------------------------------------- playback

local function map_keys()
  for action, lhs in pairs(config.keys) do
    vim.keymap.set("n", lhs, M[action], { desc = "CodeTour " .. action })
  end
end

local function unmap_keys()
  for _, lhs in pairs(config.keys) do
    pcall(vim.keymap.del, "n", lhs)
  end
end

local function render()
  clear_decorations()
  local step = state.tour.steps[state.index]
  local title = step_title(step, state.index, #state.tour.steps)
  if not step.file then
    -- content or directory step: description only
    show_float(step, title)
    return
  end

  local path = vim.fs.joinpath(state.root, step.file)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("codetour: missing file " .. path, vim.log.levels.WARN)
    show_float(step, title)
    return
  end
  -- Never open the file inside a sidebar (neo-tree, help, terminal...):
  -- such plugins reopen it elsewhere and our decorations are lost.
  if vim.bo.buftype ~= "" then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "" then
        vim.api.nvim_set_current_win(w)
        break
      end
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  state.bufs[buf] = true

  local sr, sc, er, ec = range_of(step)
  local last = vim.api.nvim_buf_line_count(buf)
  sr = math.min(sr, last - 1)
  vim.api.nvim_win_set_cursor(0, { sr + 1, 0 })
  spotlight(buf, sr, sc, er, ec)

  if config.mode == "virtual" then
    vim.cmd("normal! zz")
    show_virtual(buf, sr, step, title)
  else
    local win = vim.api.nvim_get_current_win()
    local used = show_float(step, title, win)
    -- Scroll so the spotlight sits mid-way through the region above the float.
    local uncovered = vim.api.nvim_win_get_height(win) - used
    vim.fn.winrestview({ topline = math.max(1, sr + 1 - math.floor(uncovered / 2)) })
  end
end

function M.start(path)
  if state then
    M.stop()
  end
  local tour, err = read_tour(path)
  if not tour then
    return vim.notify("codetour: " .. err, vim.log.levels.ERROR)
  end
  if #tour.steps == 0 then
    return vim.notify("codetour: tour has no steps", vim.log.levels.WARN)
  end
  hl_defaults()
  state = { tour = tour, root = root_of(path), index = 1, bufs = {} }
  map_keys()
  state.augroup = vim.api.nvim_create_augroup("codetour", { clear = true })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = state.augroup,
    callback = function()
      if state and state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
        state.win = nil
      end
    end,
  })
  render()
end

function M.next()
  if not state then
    return
  end
  if state.index >= #state.tour.steps then
    vim.notify("codetour: tour finished")
    return M.stop()
  end
  state.index = state.index + 1
  render()
end

function M.prev()
  if not state or state.index <= 1 then
    return
  end
  state.index = state.index - 1
  render()
end

function M.stop()
  if not state then
    return
  end
  clear_decorations()
  unmap_keys()
  vim.api.nvim_del_augroup_by_id(state.augroup)
  state = nil
end

-- List `.tours/**/*.tour` under the cwd and start the chosen one.
function M.pick()
  local tours = vim.fn.glob(vim.fn.getcwd() .. "/.tours/**/*.tour", false, true)
  if #tours == 0 then
    return vim.notify("codetour: no .tours/*.tour found", vim.log.levels.WARN)
  end
  if #tours == 1 then
    return M.start(tours[1])
  end
  vim.ui.select(tours, {
    prompt = "Code tour",
    format_item = function(p)
      return vim.fn.fnamemodify(p, ":t:r")
    end,
  }, function(choice)
    if choice then
      M.start(choice)
    end
  end)
end

-- Exposed for tests.
function M._state()
  return state
end

return M
