local api = vim.api

local M = {}

function M.create_buf(lines)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.bo[buf].modifiable = false
  return buf
end

function M.del_buf(buf)
  if buf and api.nvim_buf_is_valid(buf) then
    api.nvim_buf_delete(buf, { force = true })
  end
end

function M.max_elem_len(list)
  local max = 0
  for _, elem in ipairs(list) do
    max = math.max(max, #elem)
  end
  return max
end

function M.open_float(buf_or_lines, config, on_close, keymaps)
  local buf, lines
  if type(buf_or_lines) == "number" then
    buf = buf_or_lines
    if not api.nvim_buf_is_valid(buf) then
      return nil, nil, nil
    end
    lines = api.nvim_buf_get_lines(buf, 0, -1, true)
  else
    lines = buf_or_lines
    buf = M.create_buf(lines)
    vim.bo[buf].bufhidden = "wipe"
  end

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end

  config = vim.tbl_extend("keep", config or {}, {
    focus = false,
    hl = nil,
    noautocmd = true,
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
  local autocmd = nil
  if on_close then
    autocmd = api.nvim_create_autocmd(
      { "WinLeave", "BufLeave", "VimLeavePre", "VimResized" },
      {
        once = true,
        buffer = buf,
        callback = on_close,
      }
    )
    keymaps = vim.tbl_extend("keep", keymaps, {
      x = on_close,
      [":"] = on_close,
      ["<Esc>"] = on_close,
      ["<C-W>"] = "<Nop>", -- prevents some tampering with the window
    })
  end
  for lhs, rhs in pairs(keymaps) do
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true })
  end

  return win, buf, autocmd
end

function M.move_win(win, row, col)
  if win and api.nvim_win_is_valid(win) then
    api.nvim_win_set_config(win, {
      relative = "editor",
      row = row,
      col = col,
    })
  end
end

function M.close_win(win)
  if win and api.nvim_win_is_valid(win) then
    api.nvim_win_close(win, true)
  end
end

function M.blink_win(win, hl1, hl2)
  local blink_on = true
  local timer = vim.loop.new_timer()
  timer:start(
    0,
    300,
    vim.schedule_wrap(function()
      if api.nvim_win_is_valid(win) then
        local hl = blink_on and hl1 or hl2
        vim.wo[win].winhighlight = ("NormalFloat:%s,FloatBorder:%s"):format(
          hl,
          hl
        )
        blink_on = not blink_on
      end
    end)
  )
  return timer
end

function M.define_hls(hls)
  for hl, attrs in pairs(hls) do
    attrs.default = true
    api.nvim_set_hl(0, hl, attrs)
  end
end

function M.intersects(ax, ay, bx, by, bw, bh)
  return ax >= bx and ax < (bx + bw) and ay >= by and ay < (by + bh)
end

return M
