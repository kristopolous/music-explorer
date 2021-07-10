local os = require 'os'
local posix = require 'posix'

mp.enable_messages('error')

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
  print( mp.get_property_native('media-title') )
end

function quit_handler()
  mp.command('quit 5')
end

mp.register_event("log-message", lg)
mp.register_event("start-file", print_on_start)
mp.add_key_binding('o', 'openpage', openpage_handler)
mp.add_key_binding('?', 'getinfo', getinfo_handler)
mp.add_key_binding('Q', 'quit', quit_handler)

mp.add_key_binding('S', 'skip', function()
  mp.command('quit 6')
end)
mp.add_key_binding('P', 'purge', function()
  mp.command('quit 7')
end)

mp.add_key_binding('e', 'env', function() 
  for i, s in pairs(posix.getenv()) do
    print(i, s)
  end
end)

for i=1,8 do
  mp.add_key_binding(tostring(i), 'pl-' .. i, function() 
    mp.command('playlist-play-index ' .. i)
  end)
end
