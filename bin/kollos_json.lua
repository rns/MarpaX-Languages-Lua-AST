default_grammar = function()
  json[1] = { 'object' }
  json[2] = { 'array',
    fields = {
      priority = '|'
    }
  }
  object[1] = { '[', 'lcurly', 'rcurly', ']' }
  object[2] = { '[', 'lcurly', ']', 'members', '[', 'rcurly', ']',
    fields = {
      priority = '|'
    }
  }
  members[1] = { 'pair',
    fields = {
      proper = 1,
      quantifier = '*',
      separator = 'comma'
    }
  }
  pair[1] = { 'string', '[', 'colon', ']', 'value' }
  value[1] = { 'string' }
  value[2] = { 'object',
    fields = {
      priority = '|'
    }
  }
  value[3] = { 'number',
    fields = {
      priority = '|'
    }
  }
  value[4] = { 'array',
    fields = {
      priority = '|'
    }
  }
  value[5] = { 'json_true',
    fields = {
      priority = '|'
    }
  }
  value[6] = { 'json_false',
    fields = {
      priority = '|'
    }
  }
  value[7] = { 'null',
    fields = {
      priority = '|'
    }
  }
  array[1] = { '[', 'lsquare', 'rsquare', ']' }
  array[2] = { '[', 'lsquare', ']', 'elements', '[', 'rsquare', ']',
    fields = {
      priority = '|'
    }
  }
  elements[1] = { 'value',
    fields = {
      proper = 1,
      quantifier = '+',
      separator = 'comma'
    }
  }
  string[1] = { 'lstring' }
  return { json, object, members, pair, value, array, elements, string }
end

