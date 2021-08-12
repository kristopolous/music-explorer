local os = require 'os'
local io = require 'io'
local pfx = '/tmp/eb383810f22a-'
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
    mp.command('quit 2')
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
end

function record_volume()
  vol = mp.get_property('volume')
  f = io.open( pfx .. "last-volume", "w" )
  io.output(f)
  io.write(vol)
  io.close(f)
end

mp.register_event("log-message", lg)
mp.register_event("start-file", print_on_start)
mp.register_event("shutdown", record_volume)
mp.add_key_binding('o', 'openpage', openpage_handler)
mp.add_key_binding('?', 'getinfo', getinfo_handler)

for i=1,8 do
  mp.add_key_binding(tostring(i), 'pl-' .. i, function() 
    mp.command('playlist-play-index ' .. i)
  end)
end
