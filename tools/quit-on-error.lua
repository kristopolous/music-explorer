local os = require 'os'
mp.enable_messages('error')
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

mp.register_event("log-message", lg)
mp.register_event("start-file", print_on_start)
mp.add_key_binding('o', 'openpage', openpage_handler)
