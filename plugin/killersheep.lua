-- A port of Killersheep for Neovim.
--
-- Original game by Bram Moolenaar <bram@moolenaar.net>.
-- Port by Sean Dewar <https://github.com/seandewar>.
--
-- Killersheep for Vim can be found at https://github.com/vim/killersheep.
--
-- Requirements:
-- - Neovim version 0.7 or newer.
--
-- :KillKillKill  start game
--             l  move cannon right
--             h  move cannot left
--       <Space>  fire
--         <Esc>  exit game

local api = vim.api

if vim.g.loaded_killersheep then
  return
end
vim.g.loaded_killersheep = true

if vim.fn.has "nvim-0.7" == 0 then
  api.nvim_echo(
    { { "killersheep.nvim requires Neovim v0.7+", "WarningMsg" } },
    true,
    {}
  )
  return
end

api.nvim_add_user_command("KillKillKill", function(_)
  require("killersheep").start()
end, {
  desc = "Play Killersheep",
})
