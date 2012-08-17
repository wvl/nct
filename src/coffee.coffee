# A coffeescript compiler
#
coffee = require 'coffee-script'
_ = require 'underscore'

elements = 'a abbr address article aside audio b bdi bdo blockquote body button canvas caption cite code colgroup datalist dd del details dfn div dl dt em fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup html i iframe ins kbd label legend li map mark menu meter nav noscript object ol optgroup option output p pre progress q rp rt ruby s samp script section select small span strong style sub summary sup table tbody td textarea tfoot th thead time title tr u ul video'

selfClosingTags = 'area base br col command embed hr img input keygen link meta param source track wbr'

doctypes =
  'default': '<!DOCTYPE html>'
  '5': '<!DOCTYPE html>'
  'xml': '<?xml version="1.0" encoding="utf-8" ?>'
  'transitional': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
  'strict': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'
  'frameset': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">'
  '1.1': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
  'basic': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">'
  'mobile': '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">'
  'ce': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "ce-html-1.0-transitional.dtd">'

exports.compile = (template) ->
  template = if typeof template is 'function'
    template.toString()
    # "var fn = "+template.toString()
  else
    js = coffee.compile template, {bare: true}
    "function(){#{js}}"

  # console.log "Template: ", typeof template, template

  result = ""

  txt = (str='') ->
    result += str.toString()

  descend = (strOrFn) ->
    return strOrFn() if _.isFunction(strOrFn)
    val = strOrFn.toString()
    if val[0]=='@'
      txt "{ #{val.slice(1)} }"
    else
      txt val

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

  renderTag = (name, selfClosing=false) ->
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

      if selfClosing
        txt "/>"
      else
        txt ">"
        descend contents if contents
        txt "</#{name}>"
      return

  conditional = (type) ->
    (key,truthy,falsey) ->
      txt "{#{type} #{key}}"
      descend truthy
      if falsey
        txt "\n{else}"
        descend falsey
      txt "{/#{type}}"

  locals = {}
  locals.text = (text) -> txt text
  locals.ctx = (key) ->
    txt "{ #{key} }"
  locals.$if = conditional('if')
  locals.$unless = conditional('unless')
  locals.$each = (arr, body) ->
    txt "{# #{arr}}"
    descend body
    txt "{/#}"

  locals.doctype = (type='default') ->
    txt doctypes[type]

  elements.split(' ').forEach (name) -> locals[name] = renderTag(name)
  selfClosingTags.split(' ').forEach (name) -> locals[name] = renderTag(name,true)

  code = "with (locals) {"
  code += "(#{template}).call();"
  code += "}"
  # console.log "fn: ", code
  fn = new Function('locals',code)
  fn(locals)
  # console.log "result: ", result
  result
