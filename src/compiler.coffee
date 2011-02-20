
exports.tokenize = (str) ->
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

exports.compile = (src) ->
  tokens = exports.tokenize(src)
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

