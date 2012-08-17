# A coffeescript compiler
#
coffee = require 'coffee-script'
_ = require 'underscore'

exports.compile = (template) ->
  template = if typeof template is 'function'
    template.toString()
    # "var fn = "+template.toString()
  else
    js = coffee.compile template, {bare: true}
    "function(){#{js}}"

  # console.log "Template: ", typeof template, template

  result = ""

  txt = (str='') -> result += str.toString()

  renderIdClass = (str) ->
    classes = []
    id = null
    str.split('.').forEach (cls,i) ->
      if i is 0 and cls[0] == '#'
        id = cls.slice(1)
      else
        classes.push cls if cls
    txt " id=\"#{id}\"" if id
    if classes.length
      txt " class=\"#{classes.join(' ')}\""

  renderAttrs = (obj, prefix='') ->
    for k,v of obj
      # `true` is rendered as `selected="selected"`.
      v = k if typeof v is 'boolean' and v

      # Prefixed attribute.
      if typeof v is 'object' and v not instanceof Array
        # `data: {icon: 'foo'}` is rendered as `data-icon="foo"`.
        renderAttrs(v, prefix + k + '-')
      # `undefined`, `false` and `null` result in the 
      # attribute not being rendered.
      else if v or v==0
        # strings, numbers, arrays and functions are rendered "as is".
        txt " #{prefix + k}=\"#{v}\""

  renderTag = (name) ->
    (args...) ->
      # console.log "Render tag: ", name, result
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

      txt "<#{name}"
      renderIdClass idclass if idclass
      renderAttrs attrs if attrs
      txt ">"
      txt if _.isFunction(contents) then contents() else contents
      txt "</#{name}>"
      return

  locals = {}
  locals.ctx = (key) ->
    "{#{key}}"

  "div span".split(' ').forEach (name) -> locals[name] = renderTag(name)

  code = "with (locals) {"
  code += "(#{template}).call();"
  code += "}"
  # console.log "fn: ", code
  (new Function('locals',code))(locals)
  result
