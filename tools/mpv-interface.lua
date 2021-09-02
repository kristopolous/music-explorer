local os = require 'os'
local io = require 'io'
local pfx = '/tmp/eb383810f22a-'
local posix = require 'posix'

mp.enable_messages('error')

f = io.open( pfx .. "last-volume", "r" )
if f ~= nil then
  io.input(f)
  volume = io.read()
  vol = mp.set_property('volume', volume)
  io.close(f)
end

local function string_split(str, sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   str:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))      
    else
      print(formatting .. v)
    end
  end
end

function lg(e) 
  tprint(e,2)
  if e.level == "error" and e.prefix == 'stream' then
    print("Exiting...")
    mp.command('quit 1')
  end
end

function print_on_start(e,f)
  pl = mp.get_property_native("playlist", {})
  pos = mp.get_property_native("playlist-pos-1", 1)
  toprint = string.gsub(pl[pos]['filename'], "(.*/)(.*)-%d*.mp3", "%2")
  os.execute('mpv-announce "' .. toprint .. '"')
end

function openpage_handler()
  os.execute('mpv-lib open_page "' .. mp.get_property('path') .. '"')
end

function getinfo_handler()
  parts = string_split(mp.get_property('path'), '/')
  partial = parts[#parts - 2] .. '/' .. parts[#parts - 1] 
  os.execute('mpv-lib _info "' .. partial .. '"')
  print( mp.get_property_native('media-title') )
end


function record_volume()
  vol = mp.get_property('volume')
  f = io.open( pfx .. "last-volume", "w" )
  io.output(f)
  io.write(vol)
  io.close(f)
end
--
-- exit codes
--
--  1       - error
--  2       - purge
--  3 .. 5  - score
--  6       - skip
--  7       - quit and reprompt
--
-- known as player_exit in mpv-once
--

function quit_handler()
  mp.command('quit 7')
end

mp.register_event("log-message", lg)
mp.register_event("start-file", print_on_start)
mp.register_event("shutdown", record_volume)
mp.add_key_binding('o', 'openpage', openpage_handler)
mp.add_key_binding('?', 'getinfo', getinfo_handler)
mp.add_key_binding('Q', 'quit', quit_handler)

mp.add_key_binding('S', 'skip', function()
  mp.command('quit 6')
end)
mp.add_key_binding('P', 'purge', function()
  mp.command('quit 2')
end)

mp.add_key_binding('e', 'env', function() 
  for i, s in pairs(posix.getenv()) do
    print(i, s)
  end
end)

for i=2,5 do
  mp.add_key_binding(tostring(i), 'pl-' .. i, function() 
    mp.command('quit ' .. i)
  end)
end
