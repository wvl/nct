
init = (nct, _, fa) ->
  nct.escape = (str) ->
    str.toString().replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g, '&quot;').replace(/'/g, "&apos;")

  nct.templates = {}         # Template registry: name -> function
  nct.template_mapping = {}  # Tempate name: filename
  nct.reverse_mapping = {}   # filename: Template name

  nct.doRender = (tmpl, context, callback) ->
    ctx = if context instanceof nct.Context then context else new nct.Context(context)
    tmpl ctx, (err, result) ->
      return callback(err) if err
      result ctx, (err, rendered) ->
        callback(err, rendered, ctx.deps)

  # Render template that has already been registered
  nct.render = (name, context, callback) ->
    nct.load name, null, (err, tmpl) ->
      nct.doRender tmpl, context, callback


  # Load a template: from registry, or fallback to onLoad
  nct.load = (name, context, callback) ->
    if nct.templates[name]
      context.deps[nct.template_mapping[name] or name] = new Date().getTime() if context
      callback(null, nct.templates[name])
    else
      if nct.onLoad
        nct.onLoad name, (err, src, filename) ->
          nct.loadTemplate src, name
          if nct.templates[name]
            nct.template_mapping[name] = filename if filename
            nct.reverse_mapping[filename] = name if filename
            context.deps[nct.template_mapping[name] or name] = new Date().getTime() if context
            callback(null, nct.templates[name])
          else
            throw new Error("After onLoad, not found #{name}")
      else
        throw new Error("Template not found: #{name}")

  nct.filters =
    h: (v, ctx, cb) -> cb(null, nct.escape(v))
    s: (v, ctx, cb) -> cb(null, v)

    # Render as an nct template
    t: (v, ctx, cb) ->
      tmpl = nct.loadTemplate(v)
      tmpl ctx, (err, result) -> result ctx, cb

  # Evaluate and register (if given a name) a template in this function namespace
  nct.register = (tmpl, name) ->
    nct.templates[name] = tmpl


  nct.r = {}

  nct.r.applyFilters = (data, filters, context, callback) ->
    filters.splice(0, 0, 'h') unless _.include(filters, 's')
    fa.reduce filters, data, ((memo, filter, callback) ->
      callback(null, memo) unless nct.filters[filter]
      nct.filters[filter](memo, context, callback)
    ), callback

  nct.r.write = (data) ->
    return (context, callback) ->
      callback(null, (context, callback) ->
        callback(null, data))

  nct.r.mgetout = (names, params, filters) ->
    return (context, callback) ->
      context.mget names, params, (err, result, skip=false) ->
        filters.push('s') if skip
        nct.r.applyFilters result, filters, context, (err, result) ->
          callback null, (context, callback) ->
            callback(err, result)

  nct.r.getout = (name, params, filters) ->
    return (context, callback) ->
      context.get name, params, (err, result, skip=false) ->
        filters.push('s') if skip
        nct.r.applyFilters result, filters, context, (err, result) ->
          callback null, (context, callback) ->
            callback(err, result)

  nct.r.mgetout_no = (names, params, filters) ->
    return (context, callback) ->
      context.mget names, params, (err, result, skip=false) ->
        callback null, (context, callback) ->
          callback(err, result)

  nct.r.getout_no = (name, params, filters) ->
    return (context, callback) ->
      context.get name, params, (err, result, skip=false) ->
        callback null, (context, callback) ->
          callback(err, result)

  nct.r.mget = (names, params, calledfrom) ->
    return (context, callback) ->
      context.mget names, params, callback, calledfrom

  nct.r.get = (name, params, calledfrom) ->
    return (context, callback) ->
      context.get name, params, callback, calledfrom

  nct.r.doif = (query, body, elsebody=null) ->
    return (context, callback) ->
      query context, (err, result) ->
        return body(context, callback) if result
        return elsebody(context, callback) if elsebody
        callback null, (context, callback) ->
          callback(null, "")

  nct.r.multi = (commands, withstamp) ->
    return (context, callback) ->
      pending = commands.length
      results = []
      commands.forEach (command, i) ->
        command context, (err, result) ->
          results[i] = result
          callback(null, nct.r.combineResults(results)) if --pending == 0

  nct.r.each = (query, command, elsebody=null) ->
    return (context, callback) ->
      query context, (err, loopvar) ->
        if loopvar && (!_.isArray(loopvar) || !_.isEmpty(loopvar))
          if _.isArray(loopvar)
            length = loopvar.length
            fa.with_index().map loopvar, ((item, i, callback) ->
              command context.push({last: i==length-1, first: i==0}).push(item), callback
            ), (err, results) ->
              callback(null, nct.r.combineResults(results))
          else
            command context.push(loopvar), callback
        else
          if elsebody
            elsebody context, callback
          else
            callback null, (context, callback) ->
              callback(null, "")

  nct.r.block = (name, command) ->
    return (context, callback) ->
      command context, (err, block_command) ->
        callback null, (context, callback) ->
          context.blocks[name] = block_command unless context.blocks[name]
          context.blocks[name](context, callback)

  nct.r.extend = (name, command) ->
    return (context, callback) ->
      nct.load name, context, (err, base) ->
        command context, (err, child_results) ->
          base context, (err, base_results) ->
            callback null, (context, callback) ->
              child_results context, (err, result) ->
                base_results context, callback

  nct.r.partial = (name) ->
    return (context, callback) ->
      fa.if _.isFunction(name), ((cb) -> name(context, cb)), ((cb) -> cb(null, name)), (err, name) ->
        nct.load name, context, (err, thepartial) ->
          thepartial context, callback

  # include = (query) ->
  #   return (context, callback) ->
  #     query context, (err, includefile) ->
  #       path.exists includefile, (exists) ->
  #         if exists
  #           fs.readFile includefile, (err, fd) ->
  #             callback null, (context, callback) ->
  #               callback(err, fd.toString())
  #         else
  #           callback null, (ctx, cb) -> cb(null, "")

  nct.r.stamp = (query, command) ->
    return (context, callback) ->
      return callback("Stamp called from render") unless context.stamp
      query context, (err, stamping) ->
        context.stamping = stamping
        callback null, (context, callback) ->
          command context, (err, result) ->
            result context, (err, rendered) ->
              callback(err, rendered)

  nct.r.combineResults = (results) ->
    return (context, callback) ->
      fa.queue(10).reduce results, "", ((memo, result, callback) ->
        result context, (err, r) -> callback(null, memo + r)
      ), callback


  class nct.Context
    constructor: (ctx, @tail) ->
      @head = ctx
      @blocks = @tail?.blocks || {}
      @deps = @tail?.deps || {}

    getSync: (key, params, callback) ->
      ctx = this
      while ctx
        if !_.isArray(ctx.head) && typeof ctx.head == "object"
          value = ctx.head[key]
          if value != undefined
            return value
        ctx = ctx.tail
      return null

    get: (key, params, callback, calledfrom) ->
      ctx = this
      while ctx
        if !_.isArray(ctx.head) && typeof ctx.head == "object"
          value = ctx.head && ctx.head[key]
          if value != undefined
            if typeof value == "function"
              if value.length == 0
                return callback(null, value.call(ctx.head))
              else
                return value.call(ctx.head, callback, this, params, calledfrom)
            else
              return callback(null, value)
        ctx = ctx.tail
      return callback(null, "")

    # Takes an array of keys to traverse down. Does not do any
    # backtracking -- the first key will determine which object
    # we traverse down.
    mget: (keys, params, callback) ->
      this.get keys[0], [], (err, result) ->
        for k in keys.slice(1)
          if result != undefined and result != null
            try
              value = result[k]
            catch e
              return callback(null, "")

            if typeof value == "function" && value.length == 0
              result = value.call(result) 
            else
              result = value
        return callback(null, result)

    push: (newctx) ->
      return new nct.Context(newctx, this)

if typeof window is 'undefined'
  module.exports = init
else
  window.nct ?= {}
  init(window.nct, _, fa)
