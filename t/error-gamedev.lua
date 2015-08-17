-- http://www.gamedev.net/topic/542281-lua-syntax-error/
function new_scenemanager()
  return {
    function setstart (self, startscene, ...)
    -- correction: setstart = function (self, startscene, ...)

    return self.current = startscene(self, ...)
    --[[ correction:
    self.current = startscene(self, ...)
    return self.current
    --]]
    end -- missing comma

    -- see above for error/correction
    function switch(self, newscene, ...)
      self.current:unload()
      return self.current = newscene(self, ...)
    end
  }
end

