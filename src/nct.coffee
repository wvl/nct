{debug,info} = require 'triage'
_            = require 'underscore'

nct = {}

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
  nct.register(name, compile(source))

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
        pending = loopvar.length
        output = ""
        return callback(null, output) if pending == 0
        loopvar.forEach (item) ->
          command context.push(item), (err, result) ->
            output += result
            if --pending == 0
              callback(null, output)

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

tokenize = (str) ->
  # /\{\{(.*?)\}\}|\{(\#|if|else|extends|block)(.*?)\}\s*|\{\/(if|extends|block)(.*?)\}\s*/gi
  regex = ///
      \{(.*?)\}
    | ^\s*\.(if|each|extends|block|stamp)(.*?)$\n?
    | ^\s*\./(if|each|block|stamp)(.*?)$\n?
  ///gim
  index = 0
  lastIndex = null
  result = []
  while (match = regex.exec(str)) != null
    if match.index > index
      result.push(['text', str.slice(index, match.index)])
    index = regex.lastIndex
    if match[1] # variable
      # debug "matched var"
      result.push(['vararg', match[1]])
    else if match[2]
      # debug "matched if"
      result.push([match[2], match[3].trim()])
    else if match[4]
      # debug "matched /if"
      result.push(["end"+match[4], null])
    # debug "match", match
    # debug "Rest of the string", str.slice(index, str.length)
  if index < str.length
    result.push(['text', str.slice(index, str.length)])
  regex.lastIndex = 0
  result

compile = (src) ->
  tokens = tokenize(src)
  compiled = process_nodes(tokens)
  compiled

process_nodes = (tokens, processUntilFn) ->
  output = []
  while token = tokens.shift()
    break if processUntilFn && processUntilFn(token[0])
    output.push(builders[token[0]](token[1], tokens))
  if output.length > 1 then "multi(#{output.join(',')})" else output[0]

builders =
  'vararg': (token) ->
    "get('#{token}')"

  'text': (str) ->
    "write('#{escapeJs(str)}')"

  'if': (key, tokens) ->
    waselse = false
    body = process_nodes tokens, (tag) ->
      if tag=='else' || tag=='endif'
        waselse = true if tag=='else'
        return true
      else
        return false
    elsebody = if waselse
      process_nodes tokens, (tag) -> return true if tag=='endif'
    else
      null
    "doif('#{key}', #{body})" #, #{elsebody})"

  'each': (key, tokens) ->
    body = process_nodes tokens, (tag) -> tag=='endeach'
    "each('#{key}', #{body})"

  'extends': (key, tokens) ->
    body = process_nodes tokens
    "extend('#{key}', #{body})"

  'block': (key, tokens) ->
    body = process_nodes tokens, (tag) -> tag=='endblock'
    "block('#{key}', #{body})"

BS = /\\/g
CR = /\r/g
LS = /\u2028/g
PS = /\u2029/g
NL = /\n/g
LF = /\f/g
SQ = /'/g
DQ = /"/g
TB = /\t/g

escapeJs = (s) ->
  if typeof s == "string"
    return s
      .replace(BS, '\\\\')
      .replace(DQ, '\\"')
      .replace(SQ, "\\'")
      .replace(CR, '\\r')
      .replace(LS, '\\u2028')
      .replace(PS, '\\u2029')
      .replace(NL, '\\n')
      .replace(LF, '\\f')
      .replace(TB, "\\t")
  return s

module.exports = nct
module.exports.Context = Context
module.exports.tokenize = tokenize
module.exports.compile = compile
