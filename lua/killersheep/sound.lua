local api = vim.api
local fn = vim.fn

local M = {}

local PROVIDERS = {
  { exe = "afplay", cmd = { "afplay" }, ext = ".mp3" },
  { exe = "paplay", cmd = { "paplay" }, ext = ".ogg" },
  { exe = "cvlc", cmd = { "cvlc", "--play-and-exit" }, ext = ".ogg" },
}

local sound_provider
function M.detect_provider()
  sound_provider = nil
  for _, provider in ipairs(PROVIDERS) do
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
  for _, provider in ipairs(PROVIDERS) do
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
function M.stop_music()
  if music_job then
    fn.jobstop(music_job)
    music_job = nil
  end
end

local DIR = fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
  .. "/sound"
local function sound_cmd(name)
  if not sound_provider then
    return nil
  end
  local cmd = vim.deepcopy(sound_provider.cmd)
  cmd[#cmd + 1] = ("%s/%s%s"):format(DIR, name, sound_provider.ext)
  return cmd
end

function M.play_music(name)
  M.stop_music()
  local cmd = sound_cmd(name)
  if not cmd then
    return
  end
  music_job = fn.jobstart(cmd, {
    on_exit = function(_, code, _)
      if code == 0 and music_job then
        M.play_music(name)
      else
        music_job = nil
      end
    end,
  })
end

function M.play(name)
  local cmd = sound_cmd(name)
  if cmd then
    fn.jobstart(cmd)
  end
end

return M
