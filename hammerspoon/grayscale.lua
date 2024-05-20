whiteListedAppNames = {'Code', 'RubyMine', 'iTerm2', 'GitHub Desktop'}

disabled = true

function contains(list, x)
  for _, v in pairs(list) do
    if v == x then
      return true
    end
  end

  return false
end

function applicationWatcher(appName, eventType, appObject)
  if (eventType == hs.application.watcher.activated) then
    -- hs.alert.show(appName)

    if (disabled) then
      os.execute('~/zshrc/grayscale/bin/disable_grayscale')
    else
      if (contains(whiteListedAppNames, appName)) then
        os.execute('~/zshrc/grayscale/bin/disable_grayscale')
      else
        os.execute('~/zshrc/grayscale/bin/enable_grayscale')
      end
    end
  end
end

appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()
