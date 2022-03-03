local api = vim.api
local fn = vim.fn
local keymap = vim.keymap
local loop = vim.loop

local ns = api.nvim_create_namespace "killersheep"

local HIGHLIGHTS = {
  SheepTitle = { cterm = { bold = true }, bold = true },
  introHl = { ctermbg = "cyan", bg = "cyan" },

  KillerCannon = { ctermbg = "blue", bg = "blue" },
  KillerBullet = { ctermbg = "red", bg = "red" },
  KillerSheep = {
    ctermfg = "black",
    fg = "black",
    ctermbg = "green",
    bg = "green",
  },
  KillerSheep2 = {
    ctermfg = "black",
    fg = "black",
    ctermbg = "cyan",
    bg = "cyan",
  },
  KillerPoop = vim.o.background == "light"
      and { ctermbg = "black", bg = "black" }
    or { ctermbg = "white", bg = "white" },
  KillerLevel = { ctermbg = "magenta", bg = "magenta" },
  KillerLevelX = { ctermbg = "yellow", bg = "yellow" },
}
for hl, attrs in pairs(HIGHLIGHTS) do
  attrs.default = true
  api.nvim_set_hl(0, hl, attrs)
end

local function script_path()
  return fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
end
local SOUND_DIR = script_path() .. "/sound"

local SOUND_PROVIDERS = {
  afplay = { cmd = { "afplay" }, ext = ".mp3" },
  paplay = { cmd = { "paplay" }, ext = ".ogg" },
  cvlc = { cmd = { "cvlc", "--play-and-exit" }, ext = ".ogg" },
}

local sound_provider
local function detect_sound_provider()
  sound_provider = nil
  for exe, provider in pairs(SOUND_PROVIDERS) do
    if fn.executable(exe) == 1 then
      api.nvim_echo({ { "Providing sound with " .. exe .. "." } }, true, {})
      sound_provider = provider
      return
    end
  end
  local chunks = {
    { "No sound provider found; you're missing out!\n" },
    { "The following are supported: " },
    { table.concat(vim.tbl_keys(SOUND_PROVIDERS), ", ") .. "." },
  }
  api.nvim_echo(chunks, true, {})
end

local music_job
local function stop_music()
  if music_job then
    fn.jobstop(music_job)
    music_job = nil
  end
end

local function sound_cmd(name)
  if not sound_provider then
    return nil
  end
  local cmd = vim.deepcopy(sound_provider.cmd)
  cmd[#cmd + 1] = ("%s/%s%s"):format(SOUND_DIR, name, sound_provider.ext)
  return cmd
end

local function play_music(name)
  stop_music()
  local cmd = sound_cmd(name)
  if cmd then
    music_job = fn.jobstart(cmd, {
      on_exit = function(_, code, _)
        if code == 0 and music_job then
          play_music(name)
        else
          music_job = nil
        end
      end,
    })
  end
end

local function play_sound(name)
  local cmd = sound_cmd(name)
  if cmd then
    fn.jobstart(cmd)
  end
end

local function open_float(lines, config, on_close)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  config = vim.tbl_extend("keep", config or {}, {
    relative = "editor",
    border = "single",
    style = "minimal",
    width = width,
    height = #lines,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - #lines) / 2),
  })
  local win = api.nvim_open_win(buf, true, config)

  local augroup
  if on_close then
    local augroup_name = "killersheep.float" .. win
    augroup = api.nvim_create_augroup(augroup_name, {})
    api.nvim_create_autocmd({ "WinLeave", "BufLeave", "VimLeavePre" }, {
      group = augroup_name,
      once = true,
      buffer = buf,
      callback = on_close,
    })
  end

  return buf, win, augroup
end

local SHEEP_SPRITES = {
  {
    " o^^) /^^^^^^\\",
    "==___         |",
    "     \\  ___  _/",
    "      ||   ||",
  },
  {
    " o^^) /^^^^^^\\",
    "==___         |",
    "     \\_ ____ _/",
    "       |    |",
  },
  {
    " o^^) /^^^^^^\\",
    "==___         |",
    "     \\  ___  _/",
    "      ||   ||",
  },
  {
    " o^^) /^^^^^^\\",
    "==___         |",
    "     \\ _ __ _ /",
    "      / |  / |",
  },
  {
    "        /^^^^^^\\",
    "       |        |",
    " O^^)            ",
    "xx___ _         |",
    "      \\ _____  _/",
    "       ||    ||",
  },
  {
    "         /^^^^^^\\",
    "        |        |",
    "                  ",
    " O^^)             ",
    "XX___             ",
    "       \\ __  _  _/",
    "        ||    ||",
  },
}

local function level(num)
  local _, level_win = open_float({ " Level " .. num .. " " }, { row = 0 })
  vim.wo[level_win].winhighlight =
    "NormalFloat:KillerLevel,FloatBorder:KillerLevel"

  local cannon_win
  _, cannon_win = open_float(
    { "  /#\\", " /###\\", "/#####\\" },
    { border = "none", zindex = 100, row = vim.o.lines - vim.o.cmdheight - 4 }
  )
  vim.wo[cannon_win].winhighlight =
    "NormalFloat:KillerCannon,FloatBorder:KillerCannon"

  local bullet_win
  _, bullet_win = open_float(
    { "|", "|" },
    { border = "none", zindex = 80, row = vim.o.lines - vim.o.cmdheight - 5 }
  )
  vim.wo[bullet_win].winhighlight =
    "NormalFloat:KillerBullet,FloatBorder:KillerBullet"

  local sheep_win
  _, sheep_win = open_float(SHEEP_SPRITES[1], { border = "none", zindex = 90 })
  vim.wo[sheep_win].winhighlight =
    "NormalFloat:KillerSheep,FloatBorder:KillerSheep"

  local function close()
    api.nvim_win_close(level_win, true)
    api.nvim_win_close(cannon_win, true)
    api.nvim_win_close(bullet_win, true)
    api.nvim_win_close(sheep_win, true)
  end
end

local function countdown()
  local blink_timer, sound_timer = loop.new_timer(), loop.new_timer()
  local close_timer, win, augroup, _

  local function close()
    close_timer:stop()
    blink_timer:stop()
    sound_timer:stop()
    api.nvim_del_augroup_by_id(augroup)
    api.nvim_win_close(win, true)
    level(1)
  end
  _, win, augroup = open_float({
    "",
    "",
    "    Get Ready!    ",
    "",
    "",
  }, {}, close)

  local blink_on = true
  blink_timer:start(
    0,
    300,
    vim.schedule_wrap(function()
      if api.nvim_win_is_valid(win) then
        local hl = blink_on and "KillerLevelX" or "KillerLevel"
        vim.wo[win].winhighlight = ("NormalFloat:%s,FloatBorder:%s"):format(
          hl,
          hl
        )
        blink_on = not blink_on
      end
    end)
  )
  sound_timer:start(
    300,
    600,
    vim.schedule_wrap(function()
      play_sound "quack"
    end)
  )
  close_timer = vim.defer_fn(close, 2400)
end

local function intro()
  local hl_timer = loop.new_timer()
  local buf, win, augroup

  local function close()
    stop_music()
    hl_timer:stop()
    api.nvim_del_augroup_by_id(augroup)
    api.nvim_win_close(win, true)
  end
  buf, win, augroup = open_float({
    "",
    "    The sheep are out to get you!",
    "",
    " In the game:",
    "      h       move cannon left",
    "      l       move cannon right",
    "   <Space>    fire",
    "    <Esc>     quit",
    "",
    " Now press  s  to start or  x  to exit ",
    "",
  }, {}, close)

  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 1, 4, 33)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 4, 6, 7)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 5, 6, 7)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 6, 3, 10)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 7, 4, 9)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 9, 12, 13)
  api.nvim_buf_add_highlight(buf, ns, "SheepTitle", 9, 28, 29)

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
  hl_timer:start(
    0,
    300,
    vim.schedule_wrap(function()
      if api.nvim_buf_is_valid(buf) then
        hl_extmark = api.nvim_buf_set_extmark(buf, ns, 1, hl_ranges[i][1], {
          id = hl_extmark,
          hl_group = "introHl",
          end_col = hl_ranges[i][2],
        })
        i = 1 + (i % #hl_ranges)
      end
    end)
  )

  local function start()
    close()
    countdown()
  end
  keymap.set("n", "s", start, { buffer = buf })
  keymap.set("n", "S", start, { buffer = buf })
  keymap.set("n", "x", close, { buffer = buf })
  keymap.set("n", "X", close, { buffer = buf })
  keymap.set("n", "<Esc>", close, { buffer = buf })

  play_music "music"
end

local M = {}

function M.start()
  detect_sound_provider()
  intro()
end

return M
