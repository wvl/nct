
init = (nct, _) ->
  nct.cache ?= false

  nct.escape = (str) ->
    return "" unless str
    str.toString().replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g, '&quot;').replace(/'/g, "&apos;")

  nct.doRender = (tmpl, context) ->
    ctx = if context instanceof nct.Context then context else new nct.Context(context)
    tmpl ctx

  # Render template that has already been registered
  nct.render = (name, context) ->
    nct.doRender(nct.load(name), context)

  nct.templates = {}

  # Load a template: from registry, or fallback to onLoad
  nct.load = (name) ->
    return nct.templates[name] if nct.templates[name]
    src = nct.onLoad(name) if nct.onLoad
    return nct.loadTemplate(src, name) if src
    throw new Error("Template not found: #{name}")

  nct.filters = {}

  # Evaluate and register (if given a name) a template in this function namespace
  nct.register = (tmpl, name) ->
    nct.templates[name] = tmpl

  nct.r = {}

  nct.r.write = (data) ->
    (context) -> data

  applyFilters = (result, filters) ->
    filters.forEach (filter) ->
      return result unless nct.filters[filter]
      result = nct.filters[filter](result)
    result

  nct.r.mgetout = (names, params, filters) ->
    return (context, callback) ->
      result = nct.escape(context.mget(names, params))
      if filters.length then applyFilters(result, filters) else result

  nct.r.getout = (name, params, filters) ->
    return (context) ->
      result = nct.escape(context.get(name, params))
      if filters.length then applyFilters(result, filters) else result

  nct.r.mgetout_no = (names, params, filters) ->
    return (context, callback) ->
      return context.mget names, params

  nct.r.getout_no = (name, params, filters) ->
    return (context, callback) -> context.get name, params

  nct.r.mget = (names, params, calledfrom) ->
    return (context, callback) ->
      context.mget names, params, callback, calledfrom

  nct.r.get = (name, params, calledfrom) ->
    return (context, callback) ->
      context.get name, params, callback, calledfrom

  nct.r.doif = (query, body, elsebody=null) ->
    return (context, callback) ->
      result = query context
      # empty arrays should be false
      truthy = if _.isArray(result) then result.length else result
      return body(context) if truthy
      return elsebody(context) if elsebody
      ""

  nct.r.unless = (query, body) ->
    return (context, callback) ->
      result = query context
      return body(context) unless result
      ""

  nct.r.multi = (commands, withstamp) ->
    return (context) ->
      results = []
      commands.forEach (command, i) ->
        results.push command(context)
      results.join('')

  nct.r.each = (query, command, elsebody=null) ->
    return (context, callback) ->
      loopvar = query context
      if loopvar && (!_.isArray(loopvar) || !_.isEmpty(loopvar))
        if _.isArray(loopvar)
          length = loopvar.length
          result =_.map loopvar, (item, i) ->
            command context.push({last: i==length-1, first: i==0}).push(item)
          return result.join('')
        else
          return command context.push(loopvar)
      else
        if elsebody
          return elsebody context
        else
          return ""

  nct.r.partial = (name) ->
    return (context, callback) ->
      partial = nct.load (if _.isFunction(name) then name(context) else name), context
      return "" unless partial
      partial context

  nct.r.block = (name, command) ->
    return (context, callback) ->
      context.blocks[name] ?= command(context)

  nct.r.extend = (name, command) ->
    return (context, callback) ->
      base = nct.load name, context
      return "" unless base
      command(context)
      base(context)



  class nct.Context
    constructor: (ctx, @tail) ->
      @head = ctx
      @blocks = @tail?.blocks || {}
      @deps = @tail?.deps || {}

    get: (key, params, calledfrom) ->
      ctx = this
      while ctx and ctx.head
        if !_.isArray(ctx.head) and typeof ctx.head == "object"
          value = ctx.head[key]
          if value != undefined
            if typeof value == "function"
              if value.length == 0
                return value.call(ctx.head)
              else
                return value.call(ctx.head, this, params, calledfrom)
            return value
        ctx = ctx.tail
      return ""

    # Takes an array of keys to traverse down. Does not do any
    # backtracking -- the first key will determine which object
    # we traverse down.
    mget: (keys, params) ->
      result = this.get(keys[0])
      return result if result is undefined or result is null
      for k in keys.slice(1)
        try
          value = result[k]
        catch e
          return ""

        if typeof value == "function"
          result = value.call(result, this, params)
        else
          result = value
      return result

    push: (newctx) ->
      return new nct.Context(newctx, this)

if typeof window is 'undefined'
  module.exports = init
else
  window.nct ?= {}
  init(window.nct, _)
