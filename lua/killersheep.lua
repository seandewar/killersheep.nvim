local api = vim.api
local fn = vim.fn
local keymap = vim.keymap
local loop = vim.loop

local ns = api.nvim_create_namespace "killersheep"

local HIGHLIGHTS = {
  SheepTitle = { cterm = { bold = true }, bold = true },
  introHl = { ctermbg = "cyan", bg = "cyan" },
  KillerCannon = { ctermfg = "blue", fg = "blue" },
  KillerBullet = { ctermbg = "red", bg = "red" },
  KillerSheep = { ctermfg = "green", fg = "green" },
  KillerSheep2 = { ctermfg = "cyan", fg = "cyan" },
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

local SOUND_PROVIDERS = {
  { exe = "afplay", cmd = { "afplay" }, ext = ".mp3" },
  { exe = "paplay", cmd = { "paplay" }, ext = ".ogg" },
  { exe = "cvlc", cmd = { "cvlc", "--play-and-exit" }, ext = ".ogg" },
}

local sound_provider
local function detect_sound_provider()
  sound_provider = nil
  for _, provider in ipairs(SOUND_PROVIDERS) do
    if fn.executable(provider.exe) == 1 then
      api.nvim_echo(
        { { "Providing sound with " .. provider.exe .. "." } },
        true,
        {}
      )
      sound_provider = provider
      return
    end
  end

  local provider_names = {}
  for _, provider in ipairs(SOUND_PROVIDERS) do
    provider_names[#provider_names + 1] = provider.exe
  end
  if #provider_names > 0 then
    api.nvim_echo({
      { "No sound provider found; you're missing out! Supported are: " },
      { table.concat(provider_names, ", ") .. "." },
    }, true, {})
  end
end

local music_job
local function stop_music()
  if music_job then
    fn.jobstop(music_job)
    music_job = nil
  end
end

local SOUND_DIR = fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
  .. "/sound"
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
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    row = math.max(0, math.floor((vim.o.lines - vim.o.cmdheight - #lines) / 2)),
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
    " O^^)   V^V /^V^ ",
    "xx___ _^V^/  \\V^|",
    "      \\ _____  _/",
    "       ||    ||",
  },
  {
    "         /^^^^^^\\",
    "        |^  V^V  |",
    "          V^   ^V ",
    " O^^)             ",
    "XX___> ^V^V   V^V ",
    "       \\ __^V_  _/",
    "        ||    ||",
  },
}
local SHEEP_SPRITE_COLS = {}
for i, sprite in ipairs(SHEEP_SPRITES) do
  SHEEP_SPRITE_COLS[i] = 0
  for _, line in ipairs(sprite) do
    SHEEP_SPRITE_COLS[i] = math.max(SHEEP_SPRITE_COLS[i], #line)
  end
end

local sheep_sprite_bufs = {}
local function create_sheep_sprite_bufs()
  for _, lines in ipairs(SHEEP_SPRITES) do
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    vim.bo[buf].modifiable = false
    sheep_sprite_bufs[#sheep_sprite_bufs + 1] = buf
  end
end

local function del_sheep_sprite_bufs()
  for _, buf in ipairs(sheep_sprite_bufs) do
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, { force = true })
    end
  end
  sheep_sprite_bufs = {}
end

local missile_buf
local function create_missile_buf()
  missile_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(missile_buf, 0, -1, true, { "x", "|", "|" })
  vim.bo[missile_buf].modifiable = false
end

local function del_missile_buf()
  if api.nvim_buf_is_valid(missile_buf) then
    api.nvim_buf_delete(missile_buf, { force = true })
  end
  missile_buf = nil
end

local function level(level_num)
  local lines, columns = vim.o.lines, vim.o.columns
  local topline = math.max(0, lines - 50)

  local _, level_win = open_float(
    { " Level " .. level_num .. " " },
    { row = topline }
  )
  vim.wo[level_win].winhighlight =
    "NormalFloat:KillerLevel,FloatBorder:KillerLevel"

  local _, cannon_win = open_float(
    { "  /#\\", " /###\\", "/#####\\" },
    { border = "none", zindex = 100, row = lines - vim.o.cmdheight - 4 }
  )
  vim.wo[cannon_win].winhighlight =
    "NormalFloat:KillerCannon,FloatBorder:KillerCannon"

  local _, bullet_win = open_float(
    { "|", "|" },
    { border = "none", zindex = 80, row = lines - vim.o.cmdheight - 5 }
  )
  vim.wo[bullet_win].winhighlight =
    "NormalFloat:KillerBullet,FloatBorder:KillerBullet"

  local sheeps = {}
  local function close_sheep_poop_win(sheep)
    if sheep.poop_win and api.nvim_win_is_valid(sheep.poop_win) then
      api.nvim_win_close(sheep.poop_win, true)
    end
    sheep.poop_win = nil
  end

  local function update_sheep_wins(sheep)
    -- clip if partially off-screen
    local sprite_cols = SHEEP_SPRITE_COLS[sheep.sprite_index]
    local width = sprite_cols
    local anchor_right
    if sheep.col < 0 then
      width = width + sheep.col
      anchor_right = true
    elseif sheep.col > columns - width then
      width = columns - sheep.col
      anchor_right = false
    end

    if
      sheep.poop_win
      and (not sheep.poop_ticks or sheep.col + sprite_cols >= columns)
    then
      close_sheep_poop_win(sheep)
    elseif not sheep.poop_win and sheep.poop_ticks then
      -- position will be given proper values below
      sheep.poop_win = api.nvim_open_win(missile_buf, false, {
        relative = "editor",
        style = "minimal",
        border = "none",
        zindex = 100,
        width = 1,
        height = 1,
        row = 0,
        col = 0,
      })
      vim.wo[sheep.poop_win].winhighlight =
        "NormalFloat:KillerPoop,FloatBorder:KillerPoop"
    end

    api.nvim_win_set_config(sheep.win, {
      relative = "editor",
      row = sheep.row,
      col = math.max(0, sheep.col),
      width = width,
      height = #SHEEP_SPRITES[sheep.sprite_index],
    })
    api.nvim_win_set_buf(sheep.win, sheep_sprite_bufs[sheep.sprite_index])
    if anchor_right ~= nil then
      api.nvim_win_set_cursor(sheep.win, { 1, anchor_right and 9999 or 0 })
    end

    if sheep.poop_win then
      api.nvim_win_set_config(sheep.poop_win, {
        relative = "editor",
        row = sheep.row + 1,
        col = sheep.col + sprite_cols,
      })
    end
  end

  local function del_sheep(sheep)
    if sheep.death_anim_timer then
      sheep.death_anim_timer:stop()
    end
    vim.schedule(function()
      close_sheep_poop_win(sheep)
      if api.nvim_win_is_valid(sheep.win) then
        api.nvim_win_close(sheep.win, true)
      end
    end)
  end

  local LEVEL_POOP_INTERVALS = { 700, 500, 300, 200, 100 }
  local can_poop = false
  local poop_timer = loop.new_timer()
  local poop_interval = LEVEL_POOP_INTERVALS[level_num]
  poop_timer:start(poop_interval, poop_interval, function()
    can_poop = true -- next sheep that moves will poop
  end)

  local poops = {}
  local next_poop_key = 1
  local function create_poop(row, col)
    if row < 0 or col < 0 or row >= lines or col >= columns then
      return
    end
    vim.schedule(function()
      local win = api.nvim_open_win(missile_buf, false, {
        relative = "editor",
        style = "minimal",
        border = "none",
        zindex = 100,
        width = 1,
        height = 2,
        row = row,
        col = col,
      })
      api.nvim_win_set_cursor(win, { 3, 0 })
      poops[next_poop_key] = { win = win, row = row, col = col }
      next_poop_key = next_poop_key + 1
      play_sound "poop"
    end)
  end

  local function del_poop(key)
    local win = poops[key].win
    poops[key] = nil
    vim.schedule(function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end)
  end

  local function update_poop(key)
    local poop = poops[key]
    poop.row = poop.row + 1
    if poop.row >= lines - 1 then
      del_poop(key)
    else
      vim.schedule(function()
        api.nvim_win_set_config(poop.win, {
          relative = "editor",
          row = poop.row,
          col = poop.col,
        })
      end)
    end
  end

  local function kill_sheep(sheep)
    if sheep.dead then
      return
    end
    sheep.dead = true
    sheep.sprite_index = 5
    sheep.poop_ticks = nil
    play_sound "beh"

    sheep.death_anim_timer = loop.new_timer()
    sheep.death_anim_timer:start(150, 0, function()
      sheep.sprite_index = sheep.sprite_index + 1
      if sheep.sprite_index > #SHEEP_SPRITES then
        del_sheep(sheep)
      else
        vim.schedule(function()
          update_sheep_wins(sheep)
        end)
      end
    end)
  end

  local function update_sheep(sheep)
    if sheep.dead then
      return
    end
    sheep.sprite_index = 1 + (sheep.sprite_index % 4)
    local sprite_cols = SHEEP_SPRITE_COLS[sheep.sprite_index]
    local max_clip = sprite_cols - 1
    sheep.col = ((sheep.col - 1 + max_clip) % (columns + max_clip)) - max_clip

    if sheep.poop_ticks then
      sheep.poop_ticks = sheep.poop_ticks - 1
      if sheep.poop_ticks < 1 then
        sheep.poop_ticks = nil
        create_poop(
          sheep.row + #SHEEP_SPRITES[sheep.sprite_index] - 1,
          sheep.col + sprite_cols - 1
        )
      end
    elseif can_poop then
      can_poop = false
      sheep.poop_ticks = 7
    end

    vim.schedule(function()
      update_sheep_wins(sheep)
    end)
  end

  local function create_sheep(row, col, hl)
    -- position and size will be given proper values by update_sheep_wins below
    local win = api.nvim_open_win(sheep_sprite_bufs[1], false, {
      relative = "editor",
      style = "minimal",
      border = "none",
      zindex = 90,
      width = 1,
      height = 1,
      row = 0,
      col = 0,
    })
    vim.wo[win].winhighlight = ("NormalFloat:%s,FloatBorder:%s"):format(hl, hl)

    local sheep = {
      win = win,
      sprite_index = 1,
      row = row,
      col = col,
      poop_ticks = nil,
      poop_win = nil,
      dead = false,
      death_anim_timer = nil,
    }
    sheeps[#sheeps + 1] = sheep
    update_sheep_wins(sheep)
  end

  create_sheep(topline, 5, "KillerSheep")
  create_sheep(topline + 5, 75, "KillerSheep2")
  create_sheep(topline + 7, 35, "KillerSheep")
  create_sheep(topline + 10, 15, "KillerSheep")
  create_sheep(topline + 12, 70, "KillerSheep")
  create_sheep(topline + 15, 55, "KillerSheep2")
  create_sheep(topline + 20, 15, "KillerSheep2")
  create_sheep(topline + 21, 30, "KillerSheep")
  create_sheep(topline + 22, 60, "KillerSheep2")
  create_sheep(topline + 28, 0, "KillerSheep")

  local update_timer = loop.new_timer()
  update_timer:start(40, 40, function()
    for key, _ in pairs(poops) do
      update_poop(key)
    end
    for _, sheep in ipairs(sheeps) do
      update_sheep(sheep)
    end
  end)

  local function close()
    update_timer:stop()
    poop_timer:stop()
    api.nvim_win_close(level_win, true)
    api.nvim_win_close(cannon_win, true)
    api.nvim_win_close(bullet_win, true)
    for _, sheep in ipairs(sheeps) do
      del_sheep(sheep)
    end
    for key, _ in pairs(poops) do
      del_poop(key)
    end
    del_sheep_sprite_bufs()
    del_missile_buf()
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

  local HL_RANGES = {
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
        hl_extmark = api.nvim_buf_set_extmark(buf, ns, 1, HL_RANGES[i][1], {
          id = hl_extmark,
          hl_group = "introHl",
          end_col = HL_RANGES[i][2],
        })
        i = 1 + (i % #HL_RANGES)
      end
    end)
  )

  local function start()
    close()
    create_sheep_sprite_bufs()
    create_missile_buf()
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
