# A coffeescript compiler
#
coffee = require 'coffee-script'
_ = require 'underscore'

exports.compile = (template) ->
  template = if typeof template is 'function'
    "var fn = "+template.toString()
  else
    js = coffee.compile template, {bare: true}
    "var fn = function(){#{js}}"

  # console.log "Template: ", typeof template, template

  _result = ""
  _txt = (str) -> _result += str.toString()

  _idclass = (str) ->
    classes = []
    id = null
    str.split('.').forEach (cls,i) ->
      if i is 0 and cls[0] == '#'
        id = cls.slice(1)
      else
        classes.push cls if cls
    _txt " id=\"#{id}\"" if id
    if classes.length
      _txt " class=\"#{classes.join(' ')}\""

  div = (args...) ->
    contents = ''

    for a in args
      switch typeof a
        when 'function' then contents = a
        when 'object' then attrs = a
        when 'number','boolean' then contents = a
        when 'string'
          if args.length is 1
            contents = a
          else
            if a is args[0]
              idclass = a
            else
              contents = a

    _txt "<div"
    _idclass idclass if idclass
    _txt ">"
    _txt if _.isFunction(contents) then contents() else contents
    _txt "</div>"

  ctx = (key) ->
    "{#{key}}"

  eval(template)
  # console.log "fn: ", fn
  fn()
  _result
