
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
    sync.register(template, name) if name
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
    async.register(template, name) if name
    template

  async.removeTemplate = (name) ->
    if async.reverse_mapping[name]
      template_name = async.reverse_mapping[name]
      delete async.reverse_mapping[name]
      delete async.template_mapping[template_name]
      delete async.templates[template_name]
    else
      filename = async.template_mapping[name]
      delete async.reverse_mapping[filename]
      delete async.template_mapping[name]
      delete async.templates[name]

  async.clear = ->
    async.templates = {}
    async.template_mapping = {}


if typeof window is 'undefined'
  _            = require 'underscore'
  fa           = require 'fa'

  compiler     = require './compiler'

  base = {}

  base.async = {}
  require('./async')(base.async, _, fa)

  base.sync = {}
  require('./sync')(base.sync, _)

  init(compiler.compile, base.sync, base.async, _, fa)

  module.exports = base
  # module.exports.Context = nct.Context

else
  window.nct ?= {}
  init(window.nct.compile, window.nct, {}, _)

