path = require 'path'
fs   = require 'fs'
nopt = require 'nopt'
fa   = require 'fa'

nct  = require './nct'
compiler = require './compiler'
precompiler = require './coffee'

usage = '''
nct <tmpls> [-o output.js]

optional flags:
  --dir <basedir>  strip this dir from the template names
  --help           display this help and exit
  --version        display the version and exit
'''

msg_and_exit = (msg,code=0) ->
  console.log(msg)
  process.exit(code)

knownOpts =
  dir: String
  version: Boolean
  help: Boolean
  output: String

shortHands =
  d: '--dir'
  v: '--version'
  h: '--help'
  o: '--output'

exists = fs.exists || path.exists

exports.run = ->
  parsed = nopt(knownOpts, shortHands, process.argv, 2)

  if parsed.version
    json = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json')))
    msg_and_exit("nct "+json.version)

  inputs = parsed.argv.remain

  msg_and_exit(usage) if parsed.help || !inputs.length

  fa.map inputs, ((filename, callback) ->
    exists filename, (exists) ->
      return callback(new Error("Unknown file #{input}")) unless exists

      fs.readFile filename, 'utf8', (err, text) ->
        text = precompiler.compile(text) if path.extname(filename)=='.ncc'
        tmpl = compiler.compile(text)
        template_name = path.basename(filename)
        template_name = template_name.replace(parsed.dir, '') if parsed.dir
        result = "nct.register(#{tmpl}, '#{template_name}')\n"
        callback(null, result)
  ), (err, results) ->
    result = results.join('\n')
    if parsed.output
      fs.writeFile parsed.output, result, (err) ->
    else
      console.log result



