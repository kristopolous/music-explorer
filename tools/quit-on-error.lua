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
  -- os.execute('echo "' .. toprint .. '" | aosd_cat -p 2  -n "Noto Sans Condensed ExtraBold 150" -R white -f 1000 -u 15000 -o 2000 -x -20 -y 20 -d 50 -r 190 -b 216 -S black -e 2 -B black -b 200&')
end

mp.register_event("log-message", lg)
mp.register_event("start-file", print_on_start)
