{debug,info} = require 'triage'
_            = require 'underscore'
compiler     = require './compiler'

nct = {}
nct.tokenize = compiler.tokenize
nct.compile  = compiler.compile

# Template registry: name -> function
templates = {}

# Render template passed in as source template
nct.renderTemplate = (source, context, name=null, callback) ->
  callback = name if callback == undefined
  callback(null, source)

# Render template that has already been registered
nct.render = (name, context, callback) ->
  nct.load name, (err, tmpl) ->
    tmpl new Context(context, tmpl), (err, result) ->
      if tmpl.slots
        callback(err, [result, tmpl.stamped_name()])
      else
        callback(err, result)

# Load a template: from registry, or fallback to onLoad
nct.load = (name, callback) ->
  if templates[name]
    callback(null, templates[name])
  else
    throw "Template not found: #{name}"

nct.loadTemplate = (tmplStr, name) ->
  nct.register(name, nct.compile(tmplStr))

do ->
  # Compile and register a template in this function namespace
  nct.register = (name, tmpl) ->
    fn = eval(tmpl)
    re = /\{(.+?)\}/g
    while (match = re.exec(name))
      fn.slots = {} unless fn.slots
      fn.slots[match[1]] = null
    if fn.slots
      fn.stamped_name = () -> name.replace re, (matched, n) -> fn.slots[n]
    templates[name] = fn


  write = (data) ->
    return (context, callback) ->
      callback(null, data)

  get = (name) ->
    return (context, callback) ->
      context.get name, (err, result) ->
        callback(err, result)

  doif = (name, body, elsebody=null) ->
    return (context, callback) ->
      context.get name, (err, result) ->
        return body(context, callback) if result
        return elsebody(context, callback) if elsebody
        callback null, ""

  multi = (commands) ->
    return (context, callback) ->
      pending = commands.length
      return callback(null, "") if pending == 0
      results = []
      commands.forEach (command, i) ->
        command context, (err, result) ->
          results[i] = result
          if --pending == 0
            callback(null, results.join(""))

  each = (name, command) ->
    return (context, callback) ->
      context.get name, (err, loopvar) ->
        if _.isArray(loopvar)
          pending = loopvar.length
          output = ""
          return callback(null, output) if pending == 0
          loopvar.forEach (item) ->
            command context.push(item), (err, result) ->
              output += result
              if --pending == 0
                callback(null, output)
        else
          command context.push(loopvar), (err, result) ->
            callback(null, result)

  block = (name, command) ->
    return (context, callback) ->
      if context.blocks[name]
        return callback(null, context.blocks[name])
      else
        command context, (err, result) ->
          context.blocks[name] = result
          callback(null, result)

  extend = (name, command) ->
    return (context, callback) ->
      nct.load name, (err, base) ->
        command context, (err, result) ->
          base context, (err, result) ->
            callback(null, result)

  include = (name) ->
    return (context, callback) ->
      nct.load name, (err, included) ->
        included context, (err, result) ->
          callback(null, result)

  stamp = (name, command) ->
    return (context, callback) ->
      throw "No slots defined" unless context.slots
      context.get name, (err, result) ->
        throw "Stamp called with non array #{result}" unless _.isArray(result)
        _.each result, (obj) ->
          ctx = context.push(obj)
          pending = _.size(ctx.slots)
          _.each ctx.slots, (value,key) ->
            ctx.get key, (err, result) ->
              ctx.slots[key] = result
              if --pending == 0
                command ctx, callback



class Context
  constructor: (ctx, @base, @tail) ->
    @head = ctx
    @blocks = if @tail then @tail.blocks else {}
    @slots = @base.slots if @base

  wrap: (context) ->
    return context if context instanceof Context
    return new Context(new Stack(context))

  get: (key, callback) ->
    ctx = this
    while ctx
      if !_.isArray(ctx.head) && typeof ctx.head == "object"
        value = ctx.head[key]
        if value != undefined
          if typeof value == "function"
            return value(callback)
          else
            return callback(null, value)
      ctx = ctx.tail
    return callback(null, null)

  push: (newctx) ->
    return new Context(newctx, @base, this)

module.exports = nct
module.exports.Context = Context
