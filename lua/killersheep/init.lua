local api = vim.api
local loop = vim.loop

local sound = require "killersheep.sound"
local util = require "killersheep.util"

util.define_hls {
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
  SHEEP_SPRITE_COLS[i] = util.max_elem_len(sprite)
end

local CANNON_SPRITE = { "  /#\\", " /###\\", "/#####\\" }
local CANNON_SPRITE_COLS = util.max_elem_len(CANNON_SPRITE)

local LEVEL_POOP_INTERVALS = { 700, 500, 300, 200, 100 }

local function play()
  local lines, columns = vim.o.lines, vim.o.columns
  local topline = math.max(0, lines - 50)

  local cannon_buf = util.create_buf(CANNON_SPRITE)
  local missile_buf = util.create_buf { "|", "|" }
  local poop_buf = util.create_buf { "x" }
  local sheep_sprite_bufs = {}
  for _, sprite_lines in ipairs(SHEEP_SPRITES) do
    sheep_sprite_bufs[#sheep_sprite_bufs + 1] = util.create_buf(sprite_lines)
  end

  local function level(level_num)
    local sheeps = {}
    local function close_sheep_poop_win(sheep)
      util.close_win(sheep.poop_win)
      sheep.poop_win = nil
    end

    local function update_sheep_wins(sheep)
      if not api.nvim_win_is_valid(sheep.win) then
        return
      end
      -- clip if partially off-screen
      local sprite_cols = SHEEP_SPRITE_COLS[sheep.sprite_index]
      local width = sprite_cols
      local anchor_right = nil
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
        sheep.poop_win = util.open_float(poop_buf, {
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
        width = math.max(1, width),
        height = #SHEEP_SPRITES[sheep.sprite_index],
      })
      api.nvim_win_set_buf(sheep.win, sheep_sprite_bufs[sheep.sprite_index])
      if anchor_right ~= nil then
        local col = anchor_right and (sprite_cols - 1) or 0
        api.nvim_win_set_cursor(sheep.win, { 1, col })
      end
      util.move_win(sheep.poop_win, sheep.row + 1, sheep.col + sprite_cols)
    end

    local function del_sheep(sheep)
      if sheep.death_anim_timer then
        sheep.death_anim_timer:stop()
      end
      vim.schedule(function()
        util.close_win(sheep.win)
        close_sheep_poop_win(sheep)
      end)
    end

    local poop_interval = LEVEL_POOP_INTERVALS[level_num]
    local poop_timer = loop.new_timer()
    poop_timer:start(poop_interval, poop_interval, function()
      vim.schedule(function()
        local keys = vim.tbl_keys(sheeps)
        vim.tbl_filter(function(key)
          return not sheeps[key].poop_ticks
        end, keys)
        if #keys > 0 then
          sheeps[keys[1 + (vim.fn.rand() % #keys)]].poop_ticks = 7
        end
      end)
    end)

    local poops = {}
    local next_poop_key = 1
    local poop_sound_time = 0
    local function place_poop(row, col)
      if row < 0 or col < 0 or row >= lines or col >= columns then
        return
      end
      vim.schedule(function()
        local win = util.open_float(missile_buf, {
          zindex = 100,
          width = 1,
          height = 2,
          row = row,
          col = col,
          hl = "KillerPoop",
        })
        poops[next_poop_key] = { win = win, row = row, col = col }
        next_poop_key = next_poop_key + 1
        if loop.hrtime() >= poop_sound_time then
          sound.play "poop"
          poop_sound_time = loop.hrtime() + 700000000
        end
      end)
    end

    local function del_missile(table, key)
      local win = table[key].win
      table[key] = nil
      vim.schedule(function()
        util.close_win(win)
      end)
    end

    local update_timer = loop.new_timer()
    local function paused()
      return update_timer:get_due_in() == 0
    end

    local level_win, level_buf, autocmd, blink_timer, cannon, bullets
    local function close_level()
      update_timer:stop()
      poop_timer:stop()
      api.nvim_del_autocmd(autocmd)
      if blink_timer then
        blink_timer:stop()
      end
      util.close_win(level_win)
      util.close_win(cannon.win)
      util.close_win(cannon.ready_win)
      for key, _ in pairs(bullets) do
        del_missile(bullets, key)
      end
      for key, _ in pairs(poops) do
        del_missile(poops, key)
      end
      for _, sheep in ipairs(sheeps) do
        del_sheep(sheep)
      end
    end

    local function quit()
      close_level()
      for _, buf in ipairs(sheep_sprite_bufs) do
        util.del_buf(buf)
      end
      util.del_buf(cannon_buf)
      util.del_buf(missile_buf)
      util.del_buf(poop_buf)
    end

    local function end_level(won)
      update_timer:stop()
      poop_timer:stop()

      if won then
        vim.schedule(function()
          sound.play "win"
          if level_num >= 5 then
            api.nvim_echo({
              { "Amazing, you made it through ALL levels! " },
              { "(did you cheat???)", "Question" },
            }, true, {})
            vim.defer_fn(quit, 2000)
            return
          end

          vim.bo[level_buf].modifiable = true
          api.nvim_buf_set_lines(
            level_buf,
            0,
            1,
            true,
            { " Level " .. (level_num + 1) .. " " }
          )
          vim.bo[level_buf].modifiable = false
          blink_timer = util.blink_win(level_win, "KillerLevelX", "KillerLevel")
          vim.defer_fn(function()
            close_level()
            level(level_num + 1)
          end, 2000)
        end)
      else
        vim.schedule(function()
          sound.play "fail"
        end)
        vim.defer_fn(quit, 4000)
      end
    end

    local function update_poop(key)
      local poop = poops[key]
      if
        util.intersects(
          poop.col,
          poop.row + 1,
          cannon.col,
          cannon.row,
          CANNON_SPRITE_COLS,
          #CANNON_SPRITE
        )
      then
        del_missile(poops, key)
        end_level(false)
        return
      end

      poop.row = poop.row + 1
      if poop.row >= lines - 1 then
        del_missile(poops, key)
      else
        vim.schedule(function()
          util.move_win(poop.win, poop.row, poop.col)
        end)
      end
    end

    local function kill_sheep(key)
      local sheep = sheeps[key]
      sheeps[key] = nil
      sheep.sprite_index = 5
      sheep.poop_ticks = nil
      vim.schedule(function()
        sound.play "beh"
      end)

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

      if vim.tbl_count(sheeps) <= 0 then
        end_level(true)
      end
    end

    local function update_sheep(sheep)
      sheep.sprite_index = 1 + (sheep.sprite_index % 4)
      local sprite_cols = SHEEP_SPRITE_COLS[sheep.sprite_index]
      local max_clip = sprite_cols - 1
      sheep.col = ((sheep.col - 1 + max_clip) % (columns + max_clip)) - max_clip

      if sheep.poop_ticks then
        sheep.poop_ticks = sheep.poop_ticks - 1
        if sheep.poop_ticks < 1 then
          sheep.poop_ticks = nil
          place_poop(
            sheep.row + #SHEEP_SPRITES[sheep.sprite_index] - 1,
            sheep.col + sprite_cols - 1
          )
        end
      end

      vim.schedule(function()
        update_sheep_wins(sheep)
      end)
    end

    local next_sheep_key = 1
    local function place_sheep(row, col, hl)
      local sheep = {
        win = util.open_float(sheep_sprite_bufs[1], { zindex = 90, hl = hl }),
        sprite_index = 1,
        row = row,
        col = col,
        poop_ticks = nil,
        poop_win = nil,
        death_anim_timer = nil,
      }
      sheeps[next_sheep_key] = sheep
      next_sheep_key = next_sheep_key + 1
      update_sheep_wins(sheep) -- invalidate sheep size
    end

    place_sheep(topline, 5, "KillerSheep")
    place_sheep(topline + 5, 75, "KillerSheep2")
    place_sheep(topline + 7, 35, "KillerSheep")
    place_sheep(topline + 10, 15, "KillerSheep")
    place_sheep(topline + 12, 70, "KillerSheep")
    place_sheep(topline + 15, 55, "KillerSheep2")
    place_sheep(topline + 20, 15, "KillerSheep2")
    place_sheep(topline + 21, 30, "KillerSheep")
    place_sheep(topline + 22, 60, "KillerSheep2")
    place_sheep(topline + 28, 0, "KillerSheep")

    cannon = {
      row = lines - vim.o.cmdheight - #CANNON_SPRITE,
      col = math.floor((columns - 1 + CANNON_SPRITE_COLS) / 2),
      shoot_time = 0,
      win = nil,
      ready_win = nil,
    }
    local function update_cannon_wins()
      util.move_win(cannon.win, cannon.row, cannon.col)
      util.move_win(
        cannon.ready_win,
        cannon.row - 1,
        cannon.col + math.floor(CANNON_SPRITE_COLS / 2)
      )
    end

    local function move_cannon(offset)
      if not paused() then
        cannon.col = math.min(
          columns - CANNON_SPRITE_COLS,
          math.max(0, cannon.col + offset)
        )
        update_cannon_wins()
      end
    end

    bullets = {}
    local function update_bullet(key)
      local bullet = bullets[key]
      for sheep_key, sheep in pairs(sheeps) do
        if
          util.intersects(
            bullet.col,
            bullet.row,
            sheep.col,
            sheep.row,
            SHEEP_SPRITE_COLS[sheep.sprite_index],
            #SHEEP_SPRITES[sheep.sprite_index]
          )
        then
          kill_sheep(sheep_key)
          del_missile(bullets, key)
          return
        end
      end

      bullet.row = bullet.row - 2
      if bullet.row < 0 then
        del_missile(bullets, key)
      else
        vim.schedule(function()
          util.move_win(bullet.win, bullet.row, bullet.col)
        end)
      end
    end

    local next_bullet_key = 1
    local function shoot_cannon()
      if loop.hrtime() < cannon.shoot_time or paused() then
        return
      end
      local bullet = {
        row = cannon.row - 3,
        col = cannon.col + math.floor(CANNON_SPRITE_COLS / 2),
        win = nil,
      }
      bullets[next_bullet_key] = bullet
      next_bullet_key = next_bullet_key + 1
      cannon.shoot_time = loop.hrtime() + 800000000

      vim.schedule(function()
        bullet.win = util.open_float(missile_buf, {
          zindex = 100,
          width = 1,
          height = 2,
          row = bullet.row,
          col = bullet.col,
          hl = "KillerBullet",
        })
        util.close_win(cannon.ready_win)
        cannon.ready_win = nil
        sound.play "fire"
      end)
    end

    cannon.win = util.open_float(
      cannon_buf,
      { zindex = 100, hl = "KillerCannon" }
    )
    move_cannon(0) -- invalidate cannon position

    update_timer:start(50, 50, function()
      for _, sheep in pairs(sheeps) do
        update_sheep(sheep)
      end
      for key, _ in pairs(poops) do
        update_poop(key)
      end
      for key, _ in pairs(bullets) do
        update_bullet(key)
      end
      if not cannon.ready_win and loop.hrtime() >= cannon.shoot_time then
        vim.schedule(function()
          cannon.ready_win = util.open_float(
            missile_buf,
            { zindex = 100, width = 1, height = 1, hl = "KillerBullet" }
          )
          update_cannon_wins() -- invalidate bullet position
        end)
      end
    end)

    level_win, level_buf, autocmd = util.open_float(
      { " Level " .. level_num .. " " },
      {
        focus = true,
        border = "single",
        zindex = 110,
        row = topline,
        hl = "KillerLevel",
      },
      quit,
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

  level(1)
end

local function countdown()
  local blink_timer, sound_timer = loop.new_timer(), loop.new_timer()
  local close_timer, win, autocmd, _

  local function close()
    close_timer:stop()
    blink_timer:stop()
    sound_timer:stop()
    api.nvim_del_autocmd(autocmd)
    util.close_win(win)
    play()
  end
  win, _, autocmd = util.open_float({
    "",
    "",
    "    Get Ready!    ",
    "",
    "",
  }, {
    focus = true,
    border = "single",
  }, close)

  blink_timer = util.blink_win(win, "KillerLevelX", "KillerLevel")
  sound_timer:start(
    300,
    600,
    vim.schedule_wrap(function()
      sound.play "quack"
    end)
  )
  close_timer = vim.defer_fn(close, 2400)
end

local function intro()
  local hl_timer = loop.new_timer()
  local win, buf, autocmd

  local function close()
    sound.stop_music()
    hl_timer:stop()
    api.nvim_del_autocmd(autocmd)
    util.close_win(win)
  end

  local function start()
    close()
    countdown()
  end

  win, buf, autocmd = util.open_float(
    {
      "",
      "    The sheep are out to get you!",
      "",
      " In the game:",
      "      h       move cannon left",
      "      l       move cannon right",
      "   <Space>    fire",
      "    <Esc>     quit (colon also works)",
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

  local ns = api.nvim_create_namespace "killersheep"
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
  sound.play_music "music"
end

local M = {}

function M.start()
  if vim.o.columns < 60 or vim.o.lines < 35 then
    api.nvim_echo({
      { "Screen size must be at least 60x35 cells to play! ", "ErrorMsg" },
      { ("(size is %dx%d)"):format(vim.o.columns, vim.o.lines) },
    }, true, {})
    return
  end

  sound.detect_provider()
  intro()
end

return M
