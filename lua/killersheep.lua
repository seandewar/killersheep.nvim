local api = vim.api
local fn = vim.fn
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

local function create_buf(lines)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.bo[buf].modifiable = false
  return buf
end

local function del_buf(buf)
  if buf and api.nvim_buf_is_valid(buf) then
    api.nvim_buf_delete(buf, { force = true })
  end
end

local function open_float(buf_or_lines, config, on_close, keymaps)
  local buf, lines
  if type(buf_or_lines) == "number" then
    buf = buf_or_lines
    lines = api.nvim_buf_get_lines(buf, 0, -1, true)
  else
    lines = buf_or_lines
    buf = create_buf(lines)
    vim.bo[buf].bufhidden = "wipe"
  end

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end

  config = vim.tbl_extend("keep", config or {}, {
    focus = false,
    hl = nil,
    relative = "editor",
    border = "none",
    style = "minimal",
    width = width,
    height = #lines,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    row = math.max(0, math.floor((vim.o.lines - vim.o.cmdheight - #lines) / 2)),
  })
  local focus, hl = config.focus, config.hl
  config.focus = nil
  config.hl = nil

  local win = api.nvim_open_win(buf, focus, config)
  vim.wo[win].winhighlight = hl
      and ("NormalFloat:%s,FloatBorder:%s"):format(
        hl,
        hl
      )
    or ""

  keymaps = keymaps or {}
  local augroup = nil
  if on_close then
    local augroup_name = "killersheep.float" .. win
    augroup = api.nvim_create_augroup(augroup_name, {})
    api.nvim_create_autocmd({ "WinLeave", "BufLeave", "VimLeavePre" }, {
      group = augroup_name,
      once = true,
      buffer = buf,
      callback = on_close,
    })
    keymaps = vim.tbl_extend("keep", keymaps, {
      x = on_close,
      ["<Esc>"] = on_close,
    })
  end

  for lhs, rhs in pairs(keymaps) do
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true })
  end

  return win, buf, augroup
end

local function close_win(win)
  if win and api.nvim_win_is_valid(win) then
    api.nvim_win_close(win, true)
  end
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

local function play()
  local lines, columns = vim.o.lines, vim.o.columns
  local topline = math.max(0, lines - 50)

  local cannon_buf = create_buf { "  /#\\", " /###\\", "/#####\\" }
  local missile_buf = create_buf { "|", "|" }
  local poop_buf = create_buf { "x" }

  local sheep_sprite_bufs = {}
  for _, lines in ipairs(SHEEP_SPRITES) do
    local buf = create_buf(lines)
    sheep_sprite_bufs[#sheep_sprite_bufs + 1] = buf
  end

  local function quit()
    for _, buf in ipairs(sheep_sprite_bufs) do
      del_buf(buf)
    end
    del_buf(cannon_buf)
    del_buf(missile_buf)
    del_buf(poop_buf)
  end

  local LEVEL_POOP_INTERVALS = { 700, 500, 300, 200, 100 }
  local function level(level_num)
    local sheeps = {}
    local function close_sheep_poop_win(sheep)
      close_win(sheep.poop_win)
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
        sheep.poop_win = open_float(poop_buf, {
          zindex = 100,
          width = 1,
          height = 1,
          hl = "KillerPoop",
        })
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
        local col = anchor_right and (sprite_cols - 1) or 0
        api.nvim_win_set_cursor(sheep.win, { 1, col })
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
        close_win(sheep.win)
        close_sheep_poop_win(sheep)
      end)
    end

    local can_poop = false
    local poop_timer = loop.new_timer()
    local poop_interval = LEVEL_POOP_INTERVALS[level_num]
    poop_timer:start(poop_interval, poop_interval, function()
      can_poop = true -- next sheep that moves will poop
    end)

    local poops = {}
    local next_poop_key = 1
    local poop_sound_time = 0
    local function create_poop(row, col)
      if row < 0 or col < 0 or row >= lines or col >= columns then
        return
      end
      vim.schedule(function()
        local win = open_float(missile_buf, {
          zindex = 100,
          width = 1,
          height = 2,
          hl = "KillerPoop",
        })
        poops[next_poop_key] = { win = win, row = row, col = col }
        next_poop_key = next_poop_key + 1
        if loop.hrtime() >= poop_sound_time then
          play_sound "poop"
          poop_sound_time = loop.hrtime() + 700000000
        end
      end)
    end

    local function del_poop(key)
      local win = poops[key].win
      poops[key] = nil
      vim.schedule(function()
        close_win(win)
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
      sheep.death_anim_timer:start(150, 150, function()
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
      local sheep = {
        win = open_float(sheep_sprite_bufs[1], { zindex = 90, hl = hl }),
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

    local cannon = {
      row = lines - vim.o.cmdheight - 3,
      col = math.floor(columns / 2),
      shoot_time = 0,
      win = nil,
      ready_win = nil,
    }
    local function update_cannon_wins()
      api.nvim_win_set_config(cannon.win, {
        relative = "editor",
        row = cannon.row,
        col = cannon.col - 3,
      })
      if cannon.ready_win then
        api.nvim_win_set_config(cannon.ready_win, {
          relative = "editor",
          row = cannon.row - 1,
          col = cannon.col,
        })
      end
    end

    local function move_cannon(offset)
      cannon.col = math.min(columns - 3, math.max(4, cannon.col + offset))
      update_cannon_wins()
    end

    local bullets = {}
    local function del_bullet(key)
      local win = bullets[key].win
      bullets[key] = nil
      vim.schedule(function()
        close_win(win)
      end)
    end

    local function update_bullet(key)
      local bullet = bullets[key]
      bullet.row = bullet.row - 2
      if bullet.row < 0 then
        del_bullet(key)
      else
        vim.schedule(function()
          api.nvim_win_set_config(bullet.win, {
            relative = "editor",
            row = bullet.row,
            col = bullet.col,
          })
        end)
      end
    end

    local next_bullet_key = 1
    local function shoot_cannon()
      if loop.hrtime() < cannon.shoot_time then
        return
      end
      local bullet = {
        row = cannon.row - 4,
        col = cannon.col,
        win = nil,
      }
      bullets[next_bullet_key] = bullet
      next_bullet_key = next_bullet_key + 1

      vim.schedule(function()
        bullet.win = open_float(missile_buf, {
          zindex = 100,
          width = 1,
          height = 2,
          row = bullet.row,
          col = bullet.col,
          hl = "KillerBullet",
        })
        if cannon.ready_win then
          close_win(cannon.ready_win)
          cannon.ready_win = nil
        end
      end)

      cannon.shoot_time = loop.hrtime() + 800000000
      play_sound "fire"
    end

    cannon.win = open_float(cannon_buf, { zindex = 100, hl = "KillerCannon" })
    move_cannon(0) -- invalidate cannon position

    local update_timer = loop.new_timer()
    update_timer:start(50, 50, function()
      for key, _ in pairs(poops) do
        update_poop(key)
      end
      for _, sheep in ipairs(sheeps) do
        update_sheep(sheep)
      end
      for key, _ in pairs(bullets) do
        update_bullet(key)
      end
      if not cannon.ready_win and loop.hrtime() >= cannon.shoot_time then
        vim.schedule(function()
          cannon.ready_win = open_float(
            missile_buf,
            { zindex = 100, width = 1, height = 1, hl = "KillerBullet" }
          )
          update_cannon_wins() -- invalidate bullet position
        end)
      end
    end)

    local level_win
    local function close()
      update_timer:stop()
      poop_timer:stop()
      close_win(level_win)
      close_win(cannon.win)
      for key, _ in pairs(bullets) do
        del_bullet(key)
      end
      for key, _ in pairs(poops) do
        del_poop(key)
      end
      for _, sheep in ipairs(sheeps) do
        del_sheep(sheep)
      end
    end

    level_win = open_float(
      { " Level " .. level_num .. " " },
      { focus = true, border = "single", row = topline, hl = "KillerLevel" },
      nil, -- TODO
      {
        l = function()
          move_cannon(2)
        end,
        h = function()
          move_cannon(-2)
        end,
        ["<Space>"] = shoot_cannon,
      }
    )
  end

  for i = 1, #LEVEL_POOP_INTERVALS do
    level(i)
  end

  -- TODO: won!
end

local function countdown()
  local blink_timer, sound_timer = loop.new_timer(), loop.new_timer()
  local close_timer, win, augroup, _

  local function close()
    close_timer:stop()
    blink_timer:stop()
    sound_timer:stop()
    api.nvim_del_augroup_by_id(augroup)
    close_win(win)
    play()
  end
  win, _, augroup = open_float({
    "",
    "",
    "    Get Ready!    ",
    "",
    "",
  }, {
    focus = true,
    border = "single",
  }, close)

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
  local win, buf, augroup

  local function close()
    stop_music()
    hl_timer:stop()
    api.nvim_del_augroup_by_id(augroup)
    close_win(win)
  end

  local function start()
    close()
    countdown()
  end

  win, buf, augroup = open_float(
    {
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
    },
    {
      focus = true,
      border = "single",
    },
    close,
    {
      s = start,
    }
  )

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

  play_music "music"
end

local M = {}

function M.start()
  detect_sound_provider()
  intro()
end

return M
