{debug,info} = require 'triage'
_            = require 'underscore'
fa           = require 'fa'
compiler     = require './compiler'
util         = require 'util'

nct = {}
nct.tokenize = compiler.tokenize
nct.compile  = compiler.compile

# Template registry: name -> function
templates = {}
template_mapping = {}

# Render template passed in as source template
nct.renderTemplate = (source, context, name=null, callback) ->
  callback = name if callback == undefined
  callback(null, source)

# Render template that has already been registered
nct.render = (name, context, callback) ->
  nct.load name, null, (err, tmpl) ->
    ctx = new Context(context)
    tmpl ctx, (err, result) ->
      return callback(err) if err
      result ctx, (err, rendered) ->
        callback(err, rendered, ctx.deps)

stampFn = (name, command) ->
  re = /\{(.+?)\}/g
  slots = []
  while (match = re.exec(name))
    slots.push match[1]

  return (context, callback) ->
    ctx = new Context(context)

    filled_slots = {}
    fa.each slots, ((key, callback) ->
      ctx.get key, [], (err, result) ->
        filled_slots[key] = result
        callback()
    ), (err) ->
      stamped_name = name.replace /\{(.+?)\}/g, (matched, n) -> filled_slots[n]

      command ctx, (err, result) ->
        callback(err, result, stamped_name)

nct.stamp = (name, context, callback) ->
  nct.load name, null, (err, tmpl) ->
    ctx = new Context(context)
    ctx.stamp = true
    tmpl ctx, (err, result) ->
      callback(err, stampFn(name, result), ctx.deps, ctx.stamping)

# Load a template: from registry, or fallback to onLoad
nct.load = (name, context, callback) ->
  if templates[name]
    context.deps[template_mapping[name] or name] = new Date().getTime() if context
    callback(null, templates[name])
  else
    if nct.onLoad
      nct.onLoad name, (err, src, filename) ->
        nct.loadTemplate src, name
        if templates[name]
          template_mapping[name] = filename if filename
          context.deps[template_mapping[name] or name] = new Date().getTime() if context
          callback(null, templates[name])
        else
          throw new Error("After onLoad, not found #{name}")
    else
      throw new Error("Template not found: #{name}")

nct.loadTemplate = (tmplStr, name) ->
  try
    tmpl = nct.compile(tmplStr)
  catch e
    e.message = "Compile error for #{name}"
    throw e
  nct.register(name, tmpl)

nct.clear = ->
  templates = {}
  template_mapping = {}


do ->
  # Compile and register a template in this function namespace
  nct.register = (name, tmpl) ->
    # debug "Register #{name}", tmpl
    try
      templates[name] = eval(tmpl)
      null
    catch e
      e.message = "Error eval'ing compiled template: #{name}"
      throw e

  write = (data) ->
    return (context, callback) ->
      callback(null, (context, callback) ->
        callback(null, data))

  mgetout = (names, params) ->
    return (context, callback) ->
      context.mget names, params, (err, result) ->
        callback(null, (context, callback) ->
          callback(err, result))

  getout = (name, params) ->
    return (context, callback) ->
      context.get name, params, (err, result) ->
        callback(null, (context, callback) ->
          callback(err, result))

  mget = (names, params, calledfrom) ->
    return (context, callback) ->
      context.mget names, params, callback, calledfrom

  get = (name, params, calledfrom) ->
    return (context, callback) ->
      context.get name, params, callback, calledfrom

  doif = (query, body, elsebody=null) ->
    return (context, callback) ->
      query context, (err, result) ->
        return body(context, callback) if result
        return elsebody(context, callback) if elsebody
        callback null, (context, callback) ->
          callback(null, "")

  multi = (commands, withstamp) ->
    return (context, callback) ->
      pending = commands.length
      results = []
      commands.forEach (command, i) ->
        command context, (err, result) ->
          results[i] = result
          callback(null, combineResults(results)) if --pending == 0

  each = (query, command) ->
    return (context, callback) ->
      query context, (err, loopvar) ->
        if _.isArray(loopvar)
          fa.queue(10).map loopvar, ((item, callback) ->
            command context.push(item), callback
          ), (err, results) ->
            callback(null, combineResults(results))
        else
          command context.push(loopvar), callback

  block = (name, command) ->
    return (context, callback) ->
      command context, (err, block_command) ->
        callback null, (context, callback) ->
          context.blocks[name] = block_command unless context.blocks[name]
          context.blocks[name](context, callback)

  extend = (name, command) ->
    return (context, callback) ->
      nct.load name, context, (err, base) ->
        command context, (err, child_results) ->
          base context, (err, base_results) ->
            callback null, (context, callback) ->
              child_results context, (err, result) ->
                base_results context, callback

  partial = (name) ->
    return (context, callback) ->
      nct.load name, context, (err, thepartial) ->
        thepartial context, callback

  stamp = (query, command) ->
    return (context, callback) ->
      return callback("Stamp called from render") unless context.stamp
      query context, (err, stamping) ->
        context.stamping = stamping
        callback null, (context, callback) ->
          command context, (err, result) ->
            result context, (err, rendered) ->
              callback(err, rendered)

combineResults = (results) ->
  return (context, callback) ->
    fa.queue(10).reduce results, "", ((memo, result, callback) ->
      try
        result context, (err, r) -> callback(null, memo + r)
      catch e
        callback(new Error("Error rendering template"))
    ), callback


class Context
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
        value = ctx.head[key]
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
        result = result[k] if result != undefined
      return callback(null, result)

  push: (newctx) ->
    return new Context(newctx, this)

module.exports = nct
module.exports.Context = Context
