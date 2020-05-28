mp.enable_messages('error')

function lg(e) 
  if e.level == "error" then
    print("Exiting...")
    exit(2)
  end
end

mp.register_event("log-message", lg)
