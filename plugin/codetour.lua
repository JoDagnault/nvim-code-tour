if vim.g.loaded_codetour then
  return
end
vim.g.loaded_codetour = true

vim.api.nvim_create_user_command("CodeTour", function(a)
  local ct = require("codetour")
  if a.args ~= "" then
    ct.start(vim.fn.fnamemodify(a.args, ":p"))
  else
    ct.pick()
  end
end, { nargs = "?", complete = "file", desc = "Start a code tour" })

vim.api.nvim_create_user_command("CodeTourNext", function()
  require("codetour").next()
end, { desc = "Next tour step" })

vim.api.nvim_create_user_command("CodeTourPrev", function()
  require("codetour").prev()
end, { desc = "Previous tour step" })

vim.api.nvim_create_user_command("CodeTourStop", function()
  require("codetour").stop()
end, { desc = "End the tour" })
