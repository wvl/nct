
init = (compile, sync, async, _, fa) ->
  stampFn = (name, command) ->
    re = /\{(.+?)\}/g
    slots = []
    while (match = re.exec(name))
      slots.push match[1]

    return (context, callback) ->
      ctx = if context instanceof async.Context then context else new async.Context(context)

      filled_slots = {}
      fa.each slots, ((key, callback) ->
        ctx.get key, [], (err, result) ->
          filled_slots[key] = result
          callback()
      ), (err) ->
        stamped_name = name.replace /\{(.+?)\}/g, (matched, n) -> filled_slots[n]

        command ctx, (err, result) ->
          callback(err, result, stamped_name, ctx.deps)

  async.stamp = (name, context, callback) ->
    async.load name, null, (err, tmpl) ->
      ctx = new async.Context(context)
      ctx.stamp = true
      tmpl ctx, (err, result) ->
        callback(err, stampFn(name, result), ctx.deps, ctx.stamping)

  # Render template passed in as source template
  sync.renderTemplate = (source, context, name) ->
    tmpl = sync.loadTemplate(source, name)
    sync.doRender tmpl, context

  sync.loadTemplate = (tmplStr, name=null) ->
    tmpl = compile(tmplStr)
    nct = sync
    template = eval(tmpl)
    sync.register(template, name) if name and sync.cache
    template

  async.renderTemplate = (source, context, name, callback) ->
    if !callback
      callback = name
      name = null

    tmpl = async.loadTemplate(source, name)
    async.doRender tmpl, context, callback

  async.loadTemplate = (tmplStr, name=null) ->
    tmpl = compile(tmplStr)
    nct = async
    template = eval(tmpl)
    async.register(template, name) if name and async.cache
    template

  async.removeTemplate = (name) ->
    delete async.template_mapping[name]
    delete async.templates[name]

  async.clear = ->
    async.templates = {}
    async.template_mapping = {}


if typeof window is 'undefined'
  _            = require 'underscore'
  fa           = require 'fa'
  fs           = require 'fs'
  path         = require 'path'


  base = {}
  base.compiler     = require './compiler'
  base.coffee       = require './coffee'
  require('./sync')(base, _)

  base.async = {}
  require('./async')(base.async, _, fa)


  init(base.compiler.compile, base, base.async, _, fa)

  module.exports = base

  # comply with express api?
  # base.compile = (str, options) ->
  #   base.onLoad = (name) ->
  #     filename = path.join(options.root, "#{name}.nct")
  #     existsSync = fs.existsSync || path.existsSync
  #     return fs.readFileSync(filename).toString() if existsSync(filename)
  #     null

  #   # console.log "compile?", options
  #   base.cache = options?.settings?.env=='production'
  #   tmpl = base.loadTemplate(str)
  #   (ctx) -> base.doRender(tmpl, ctx)

else
  window.nct ?= {}
  init(window.nct.compile, window.nct, {}, _)

