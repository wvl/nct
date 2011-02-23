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
  nct.load name, null, (err, tmpl) ->
    tmpl.deps = []
    tmpl new Context(context, tmpl), (err, result, data) ->
      if data && data.slots
        debug "data", data
        callback(err, result, tmpl.stamped_name(data.slots), data.finished)
      else
        debug "no data?"
        callback(err, result)

nct.deps = (name) ->
  if templates[name] then templates[name].deps else []

# Load a template: from registry, or fallback to onLoad
nct.load = (name, context, callback) ->
  if templates[name]
    context.deps.push(name) if context
    callback(null, templates[name])
  else
    if nct.onLoad
      nct.onLoad name, (err, src) ->
        nct.loadTemplate src, name
        if templates[name]
          context.deps.push(name) if context
          callback(null, templates[name])
        else
          throw "After onLoad, not found #{name}"
    else
      throw "Template not found: #{name}"

nct.loadTemplate = (tmplStr, name) ->
  nct.register(name, nct.compile(tmplStr))


do ->
  # Compile and register a template in this function namespace
  nct.register = (name, tmpl) ->
    debug "Register #{name}", tmpl
    fn = eval(tmpl)
    re = /\{(.+?)\}/g
    while (match = re.exec(name))
      fn.slots = {} unless fn.slots
      fn.slots[match[1]] = null
    if fn.slots
      fn.stamped_name = (slots) -> name.replace re, (matched, n) -> slots[n]
    templates[name] = fn


  write = (data) ->
    return (context, callback) ->
      callback(null, data)

  mget = (names, params) ->
    return (context, callback) ->
      context.mget names, params, callback

  get = (name, params) ->
    return (context, callback) ->
      context.get name, params, callback

  doif = (query, body, elsebody=null) ->
    return (context, callback) ->
      query context, (err, result) ->
        return body(context, callback) if result
        return elsebody(context, callback) if elsebody
        callback null, ""

  multi = (commands, withstamp) ->
    if withstamp
      stamp_index = withstamp-1
      stamps = []
      results = []

      return (context, callback) ->
        pending = commands.length
        stamp_length = null

        commands.forEach (command, i) ->
          command context, (err, result, datum) ->
            results[i] = result

            if i==stamp_index
              stamp_length = datum.length unless stamp_length
              if pending == 1
                datum.finished = --stamp_length == 0
                debug "Multi Return", datum
                callback(null, results.join(""), datum)
                while (stampresult = stamps.pop())
                  results[stamp_index] = stampresult[0]
                  datum = stampresult[1]
                  datum.finished = --stamp_length == 0
                  debug "Multi Return Loop", datum
                  callback(null, results.join(""), datum)
              else
                stamps.push([result, datum])
            else if --pending==1 && stamps.length
              while (stampresult = stamps.pop())
                results[stamp_index] = stampresult[0]
                datum = stampresult[1]
                datum.finished = --stamp_length == 0
                debug "Multi return from non stamp", datum
                callback(null, results.join(""), datum)
    else
      return (context, callback) ->
        pending = commands.length

        results = []
        data = null
        commands.forEach (command, i) ->
          command context, (err, result, datum) ->
            results[i] = result
            data = datum if datum
            callback(null, results.join(""), data) if --pending == 0



  each = (query, command) ->
    return (context, callback) ->
      query context, (err, loopvar) ->
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
          command context.push(loopvar), callback

  block = (name, command) ->
    return (context, callback) ->
      if context.blocks[name]
        return callback(null, context.blocks[name][0], context.blocks[name][1])
      else
        command context, (err, result, data) ->
          context.get '__stamp', (err, instamp) ->
            context.blocks[name] = [result, data] #unless instamp
            callback(null, result, data)

  extend = (name, command) ->
    return (context, callback) ->
      debug "Extend #{name}"
      nct.load name, context, (err, base) ->
        command context, (err, result, data) ->
          base context, (err, result) ->
            callback(err, result, data)


  include = (name) ->
    return (context, callback) ->
      nct.load name, context, (err, included) ->
        included context, callback

  stamp = (query, command) ->
    return (context, callback) ->
      throw "No slots defined" unless context.slots
      query context, (err, result) ->
        throw "Stamp called with non array #{result}" unless _.isArray(result)
        length = pending = result.length
        _.each result, (obj) ->
          debug "In Stamp", obj
          ctx = context.push({'__stamp': true}).push(obj)
          numslots = _.size(ctx.slots)
          slots = _.clone(ctx.slots)
          _.each slots, (value,key) ->
            ctx.get key, (err, result) ->
              slots[key] = result
              if --numslots == 0
                finished = --pending == 0
                command ctx, (err, result) ->
                  debug "stamped #{finished}", result, slots
                  callback(err, result, {slots: slots, length: length, finished: finished})



class Context
  constructor: (ctx, @base, @tail) ->
    @head = ctx
    @blocks = if @tail then @tail.blocks else {}
    @slots = @base.slots
    @deps = @base.deps

  get: (key, params, callback) ->
    if callback == undefined
      callback = params
      params = null
    ctx = this
    while ctx
      if !_.isArray(ctx.head) && typeof ctx.head == "object"
        value = ctx.head[key]
        if value != undefined
          if typeof value == "function"
            return value(callback, this, params)
          else
            return callback(null, value)
      ctx = ctx.tail
    return callback(null, null)

  # Takes an array of keys to traverse down. Does not do any
  # backtracking -- the first key will determine which object
  # we traverse down.
  mget: (keys, params, callback) ->
    callback = params if callback == undefined
    this.get keys[0], (err, result) ->
      for k in keys.slice(1)
        result = result[k] if result != undefined
      return callback(null, result)

  push: (newctx) ->
    return new Context(newctx, @base, this)

module.exports = nct
module.exports.Context = Context
