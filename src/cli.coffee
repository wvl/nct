path = require 'path'
fs   = require 'fs'
sys  = require 'sys'
nopt = require 'nopt'
fa   = require 'fa'

nct  = require './nct'

usage = '''
nct <tmpls> [-o output.js]

optional flags:
  --help    display this help and exit
  --version display the version and exit
'''

msg_and_exit = (msg,code=0) ->
  sys.puts(msg)
  process.exit(code)

knownOpts =
  version: Boolean
  help: Boolean
  output: String

shortHands =
  v: '--version'
  h: '--help'
  o: '--output'

parsed = nopt(knownOpts, shortHands, process.argv, 2)

msg_and_exit(usage) if parsed.help

if parsed.version
  package = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json')))
  msg_and_exit("nct "+package.version)

inputs = parsed.argv.remain


fa.map inputs, ((input, callback) ->
  path.exists input, (exists) ->
    return callback(new Error("Unknown file #{input}")) unless exists

    fs.readFile input, (err, fd) ->
      tmpl = nct.compileToString(fd.toString(), input)
      callback(null, tmpl)
), (err, results) ->
  result = results.join('\n')
  if parsed.output
    fs.writeFile parsed.output, result, (err) ->
  else
    console.log result



