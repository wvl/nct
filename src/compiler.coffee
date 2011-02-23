{debug,info} = require 'triage'

tokenize = (str) ->

  parse_args = (input) ->
    segments = input.trim().split(/\s+/)
    segments[0] = segments[0].split('.') #if /\./.test(segments[0])
    segments

  # /\{\{(.*?)\}\}|\{(\#|if|else|extends|block)(.*?)\}\s*|\{\/(if|extends|block)(.*?)\}\s*/gi
  regex = ///
      \{(.*?)\}
    | ^\s*\.(if|\#|\>|else|extends|block|stamp)(.*?)$\n?
    | ^\s*\./(if|\#|block|stamp)(.*?)$\n?
  ///gim
  index = 0
  lastIndex = null
  result = []
  while (match = regex.exec(str)) != null
    if match.index > index # pre match
      result.push(['text', str.slice(index, match.index)])

    index = regex.lastIndex
    if match[1] # variable
      [key, params...] = parse_args(match[1])
      result.push(['vararg', key, params])
    else if match[2]
      if match[2] == 'text'
        result.push(['text', match[3]])
      else if match[2] == '>' or match[2] == 'extends' or match[2] == 'block'
        result.push([match[2], match[3].trim(), null])
      else
        [key, params...] = parse_args(match[3])
        result.push([match[2], key, params])
    else if match[4]
      result.push(["end"+match[4], null])

  if index < str.length # post match
    result.push(['text', str.slice(index, str.length)])
  regex.lastIndex = 0
  result

process_nodes = (tokens, processUntilFn) ->
  output = []
  while token = tokens.shift()
    break if processUntilFn && processUntilFn(token[0])
    output.push(builders[token[0]](token[1], token[2], tokens))
  if output.length > 1 then "multi([#{output.join(',')}])" else output[0]


builders =
  'vararg': (key, params) ->
    paramargs = params.map (p) -> "'#{p}'"
    paramargs = "[#{paramargs.join(',')}]"
    if key.length > 1
      toks = key.map (t) -> "'#{t}'"
      "mget([#{toks.join(',')}], #{paramargs})"
    else
      "get('#{key.join(',')}', #{paramargs})"

  'text': (str) ->
    "write('#{escapeJs(str)}')"

  'if': (key,params,tokens) ->
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
    query = builders['vararg'](key, params)
    "doif(#{query}, #{body}" + if elsebody then ", #{elsebody})" else ")"

  '#': (key,params,tokens) ->
    query = builders['vararg'](key, params)
    body = process_nodes tokens, (tag) -> tag=='end#'
    "each(#{query}, #{body})"

  '>': (key,ignore,tokens) ->
    "include('#{key}')"

  'stamp': (key, params, tokens) ->
    body = process_nodes tokens, (tag) -> tag=='endstamp'
    "stamp('#{key}', #{body})"

  'extends': (key, ignore, tokens) ->
    body = process_nodes tokens
    "extend('#{key}', #{body})"

  'block': (key, ignore, tokens) ->
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

exports.compile = (src) ->
  process_nodes(tokenize(src))

