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

usage_and_exit = (code=0) ->
  sys.puts(usage)
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

usage_and_exit() if parsed.help

if parsed.version
  console.log "nct #{nct.version.join('.')}"
  process.exit(0)

inputs = parsed.argv.remain


fa.map inputs, ((input, callback) ->
  path.exists input, (exists) ->
    return callback(new Error("Unknown file #{input}")) unless exists

    fs.readFile input, (err, fd) ->
      tmpl = nct.compile fd.toString()
      callback(null, "nct.register('''#{tmpl}''', input)")
), (err, results) ->
  console.log results.join("\n")



