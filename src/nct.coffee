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
    ctx = if context instanceof Context then context else new Context(context)
    tmpl ctx, (err, result) ->
      callback(err, result)

# Compile and register source template
nct.loadTemplate = (source, name) ->
  nct.register(name, nct.compile(source))

# Load a template: from registry, or fallback to onLoad
nct.load = (name, callback) ->
  if templates[name]
    callback(null, templates[name])
  else
    throw "Template not found: #{name}"

do ->
  # Eval a compiled template in this function namespace
  nct.register = (name, templateString) ->
    templates[name] = eval(templateString)

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

  multi = (commands...) ->
    return (context, callback) ->
      pending = commands.length
      return callback(null, "") if pending == 0
      results = []
      commands.forEach (command, i) =>
        command context, (err, result) =>
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


class Context
  constructor: (ctx, @tail) ->
    @head = ctx
    @blocks = if @tail then @tail.blocks else {}

  wrap: (context) ->
    return context if context instanceof Context
    return new Context(new Stack(context))

  get: (key, callback) ->
    ctx = this
    while ctx
      if !_.isArray(ctx.head) && typeof ctx.head == "object"
        value = ctx.head[key]
        if value != undefined
          if _.isFunction(value)
            return value(callback)
          else
            return callback(null, value)
      ctx = ctx.tail
    return callback(null, null)

  push: (newctx) ->
    return new Context(newctx, this)

module.exports = nct
module.exports.Context = Context
