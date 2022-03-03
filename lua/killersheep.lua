local api = vim.api
local fn = vim.fn
local keymap = vim.keymap
local loop = vim.loop

local ns = api.nvim_create_namespace "killersheep"
api.nvim_set_hl(0, "SheepTitle", { cterm = { bold = true }, bold = true })
api.nvim_set_hl(0, "IntroHl", { ctermbg = "cyan", bg = "cyan" })

local function script_path()
  return fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
end

local SOUND_PROVIDERS = {
  afplay = { cmd = "afplay", ext = ".mp3" },
  paplay = { cmd = "paplay", ext = ".ogg" },
  cvlc = { cmd = "cvlc --play-and-exit", ext = ".ogg" },
}
local sound_provider

local function detect_sound_provider()
  sound_provider = nil
  for provider, _ in pairs(SOUND_PROVIDERS) do
    if fn.executable(provider) then
      sound_provider = provider
      return
    end
  end
  api.nvim_echo(
    { { "No sound provider found, you are missing out!" } },
    true,
    {}
  )
end

local function countdown()
  -- TODO
end

local function intro()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, true, {
    "",
    "    The sheep are out to get you!",
    "",
    " In the game:",
    "      h       move cannon left",
    "      l       move cannon right",
    "   <Space>    fire",
    "    <Esc>     quit (colon also works)",
    "",
    " Now press  s  to start or  x  to exit",
  })
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 1, 4, 33)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 4, 6, 7)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 5, 6, 7)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 6, 3, 10)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 7, 4, 9)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 9, 12, 13)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 9, 28, 29)

  local width, height = 39, 11
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    border = "single",
    style = "minimal",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
  })

  local hl_ranges = {
    { 4, 7 },
    { 8, 13 },
    { 14, 17 },
    { 18, 21 },
    { 22, 24 },
    { 25, 28 },
    { 29, 33 },
  }
  local i = 1
  local hl_extmark
  local hl_timer = loop.new_timer()
  hl_timer:start(
    0,
    300,
    vim.schedule_wrap(function()
      if api.nvim_buf_is_valid(buf) then
        hl_extmark = api.nvim_buf_set_extmark(buf, ns, 1, hl_ranges[i][1], {
          id = hl_extmark,
          hl_group = "IntroHl",
          end_col = hl_ranges[i][2],
        })
        i = 1 + (i % #hl_ranges)
      end
    end)
  )

  local augroup = api.nvim_create_augroup("killersheep.intro", {})

  local function close()
    hl_timer:stop()
    api.nvim_del_augroup_by_id(augroup)
    api.nvim_win_close(win, true)
  end

  api.nvim_create_autocmd({ "WinLeave", "BufLeave", "VimLeavePre" }, {
    group = "killersheep.intro",
    once = true,
    buffer = buf,
    callback = close,
  })

  keymap.set("n", "s", countdown)
  keymap.set("n", "S", countdown)
  keymap.set("n", "x", close)
  keymap.set("n", "X", close)
  keymap.set("n", "<Esc>", close)
end

local M = {}

function M.start(sounddir)
  sounddir = sounddir or (script_path() .. "/sound")
  detect_sound_provider()
  intro()
end

return M
