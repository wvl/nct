{debug,info} = require 'triage'
_            = require 'underscore'
compiler     = require './compiler'

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
    tmpl.deps = []
    pending = null
    tmpl new Context(context, tmpl), (err, result) ->
      pending = result.iterations unless pending
      if tmpl.stamped_name
        callback(err, result.rendered, tmpl.stamped_name(result.slots), --pending==0)
      else
        callback(err, result.rendered, name, true)

nct.deps = (name) ->
  if templates[name] then templates[name].deps else []

# Load a template: from registry, or fallback to onLoad
nct.load = (name, context, callback) ->
  if templates[name]
    context.deps.push(template_mapping[name] or name) if context
    callback(null, templates[name])
  else
    if nct.onLoad
      nct.onLoad name, (err, src, filename) ->
        nct.loadTemplate src, name
        if templates[name]
          template_mapping[name] = filename if filename
          context.deps.push(filename or name) if context
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
    result = new Result(data)
    return (context, callback) ->
      callback(null, result)

  mgetout = (names, params) ->
    return (context, callback) ->
      context.mget names, params, (err, result) ->
        callback(err, new Result(result))

  getout = (name, params) ->
    return (context, callback) ->
      context.get name, params, (err, result) ->
        callback(err, new Result(result))

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
        callback null, new Result() 

  multi = (commands, withstamp) ->
    if withstamp
      stamp_index = withstamp-1

      return (context, callback) ->
        pending = commands.length
        results = []
        stamps = []

        commands.forEach (command, i) ->
          command context, (err, result) ->
            results[i] = result

            if i==stamp_index
              if pending == 1
                callback(null, joinResults(results))
                while (stampresult = stamps.pop())
                  results[stamp_index] = stampresult
                  callback(null, joinResults(results))
              else
                stamps.push(result)
            else if --pending==1 && stamps.length
              while (stampresult = stamps.pop())
                results[stamp_index] = stampresult
                callback(null, joinResults(results))
    else
      return (context, callback) ->
        pending = commands.length
        results = []
        commands.forEach (command, i) ->
          command context, (err, result) ->
            results[i] = result
            if pending == 1
              output = joinResults(results)
            callback(null, joinResults(results)) if --pending==0



  each = (query, command) ->
    return (context, callback) ->
      query context, (err, loopvar) ->
        if _.isArray(loopvar)
          pending = loopvar.length
          output = new Result()
          return callback(null, output) if pending == 0
          loopvar.forEach (item) ->
            command context.push(item), (err, r) ->
              output.join(r)
              if --pending == 0
                callback(null, output)
        else
          command context.push(loopvar), callback

  block = (name, command) ->
    return (context, callback) ->
      command context, (err, result) ->
        b = new Result("<<block:#{name}>>")
        b.blocks[name] = result
        callback(null, b)

  extend = (name, command) ->
    return (context, callback) ->
      nct.load name, context, (err, base) ->
        base context.push({'__extended': true}), (err, base_results) ->
          command context, (err, child_results) ->
            result = new Result(base_results.rendered).merge(base_results).merge(child_results)
            context.get '__extended', (err, extended) ->
              result = result.fill() unless extended
              callback(err, result)


  include = (name) ->
    return (context, callback) ->
      nct.load name, context, (err, included) ->
        included context, callback

  stamp = (query, command) ->
    return (context, callback) ->
      throw "No slots defined" unless context.slots
      query context, (err, iterator) ->
        throw "Stamp called with non array #{iterator}" unless _.isArray(iterator)
        _.each iterator, (obj) ->
          ctx = context.push(obj)
          command ctx, (err, result) ->
            result.iterations = iterator.length
            result.fillSlots ctx, callback

# Result is the class for holding the return values of any command.
# It holds the rendered string, plus stamped slot data, and rendered blocks.
class Result
  constructor: (@rendered="", @blocks={}) ->
    @iterations = 1

  join: (other) ->
    @rendered += other.rendered
    @iterations = @iterations * other.iterations
    @slots = other.slots if other.slots
    _.extend(@blocks, other.blocks)
    this

  merge: (other) ->
    @iterations = @iterations * other.iterations
    @slots = other.slots if other.slots
    _.extend(@blocks, other.blocks)
    this

  fillSlots: (context, callback) ->
    @slots = _.clone(context.slots)
    numslots = _.size(context.slots)
    _.each @slots, (value,key) =>
      context.get key, (err, result) =>
        @slots[key] = result
        callback(null, this) if --numslots == 0

  fill: () ->
    regex = /\<\<block:(.+?)\>\>/g
    @rendered = @rendered.replace regex, (str, name) =>
      @blocks[name].rendered
    this

# Sums up an array of results
joinResults = (results) ->
  _.reduce(results, ((memo, r) -> memo.join(r)), new Result())


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
            if value.length == 0
              return callback(null, value.call(ctx.head))
            else
              return value.call(ctx.head, callback, this, params)
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
