fs = require 'fs'
path = require 'path'
util = require 'util'
fa = require 'fa'
nct = if window? then require('nct') else require path.join(__dirname, "../lib/nct")
_ = require 'underscore'

suite "nct tests", {serial: true, stopOnFail: false}

atest "New Context", (t) ->
  ctx = new nct.Context({"title": "hello"}, {})
  ctx.get 'title', [], (err, result) ->
    t.same "hello", result
    t.done()

atest "Context push", (t) ->
  ctx = new nct.Context({"title": "hello"}, {})
  ctx = ctx.push({"post": "Hi"})
  ctx.get 'title', [], (err, result) ->
    t.same "hello", result
    ctx.get 'post', [], (err, result) ->
      t.same 'Hi', result
      t.done()

atest "Async function in context", (t) ->
  fn = (cb) ->
    process.nextTick () -> cb(null, "Hi Async!")
  ctx = new nct.Context({"title": fn}, {})
  ctx.get 'title', [], (err, result) ->
    t.same "Hi Async!", result
    t.done()

atest "Context with synchronous function", (t) ->
  ctx = new nct.Context({"title": () -> "Hello World"}, {})
  ctx.get 'title', [], (err, result) ->
    t.same "Hello World", result
    t.done()

atest "Context.get from null", (t) ->
  ctx = new nct.Context(null)
  ctx.get 'title', [], (err, result) ->
    t.same null, result
    t.done()


contextAccessors = [
  [["title"], {title: "Hello"}, "Hello"]
  [["post","title"], {post: {title: "Hello"}}, "Hello"]
  [["post","blah"], {post: ["Hello"]}, undefined]
  [["post","blah","blah"], {post: ["Hello"]}, undefined]
  [["post","isnull","blah"], {post: null}, null]
]

contextAccessors.forEach ([attrs, context, expected]) ->
  atest "Context accessors #{attrs}", (t) ->
    ctx = new nct.Context(context, {})
    ctx.mget attrs, [], (err, result) ->
      t.same expected, result
      t.done()


cbGetFn = (cb, ctx, params) -> ctx.get(params[0], [], cb)

compileAndRenders = [
  ["Hello", {}, "Hello"]
  ["Hello {title}", {title: "World!"}, "Hello World!"]
  ["Hello { title }", {title: "World!"}, "Hello World!"]
  ["Hello {person.name}", {person: {name: "Joe"}}, "Hello Joe"]
  ["Hello {person.name}", {person: (-> {name: "Joe"})}, "Hello Joe"]
  ["Hello {person.name}", {person: (-> {name: (-> "Joe")})}, "Hello Joe"]
  ["Hello {content name}", {content: cbGetFn, name: 'Joe'}, "Hello Joe"]
  [".if content post\n{post.title}\n./if", {content: cbGetFn, post: {title: 'Hello'}}, "Hello\n"]
  [".# content post\n{title}\n./#", {content: cbGetFn, post: {title: 'Hello'}}, "Hello\n"]
  [".if doit\n{name}\n./if", {doit: true, name: "Joe"}, "Joe\n"]
  [".if nope\n{name}\n./if", {nope: false, name: "Joe"}, ""]
  [".if doit\n{name}\n.else\nNoope\n./if", {doit: false, name: "Joe"}, "Noope\n"]
  [".# posts\n{title}\n./#", {posts: [{'title': 'Hello'},{'title':'World'}]}, "Hello\nWorld\n"]
  [".# person\n{name}\n./#", {person: {'name': 'Joe'}}, "Joe\n"]
  [".# person\n./#", {person: {'name': 'Joe'}}, ""]
  [".# person\n.else\nNope\n./#", {person: []}, "Nope\n"]

  ["{if content post}{post.title}{/if}", {content: cbGetFn, post: {title: 'Hello'}}, "Hello"]
  ["{# person}{name}{/# person}", {person: {'name': 'Joe'}}, "Joe"]

  ["{ noescape | s }", {noescape: "<h1>Hello</h1>"}, "<h1>Hello</h1>"]
  ["{ blah | s | t | h}", {}, ""]
  ["{ escape }", {escape: "<h1>Hello</h1>"}, "&lt;h1&gt;Hello&lt;/h1&gt;"]
]

compileAndRenders.forEach ([tmpl,ctx,toequal]) ->
  atest "CompAndRender #{nct.escape(tmpl.replace(/\n/g,' | '))}", (t) ->
    nct.renderTemplate tmpl, ctx, (err, result) ->
      t.same toequal, result
      t.done()

atest "template filter", (t) ->
  nct.renderTemplate "{ body | t }", {body: "{realbody}", realbody: "Hello!"}, (err, result) ->
    t.same "Hello!", result
    t.done()

atest "CompAndRender extends", (t) ->
  nct.loadTemplate ".extends base\nHello\n.block main\nt\n./block", "t"
  nct.loadTemplate "Base\n.block main\nBase\n./block", "base"
  nct.render "t", {}, (err, result, deps) ->
    t.same ["base"], Object.keys(deps)
    t.same "Base\nt\n", result
    t.done()

atest "CompAndRender extends 3 levels", (t) ->
  nct.loadTemplate ".extends med\nHello\n.block main\nMAIN\n./block", "t"
  nct.loadTemplate ".extends base\n.block sidebar\nSIDEBAR\n./block", "med"
  nct.loadTemplate "BASE\n.block main\nBASEMAIN\n./block\n.block sidebar\nsidebar base\n./block", "base"
  nct.render "t", {}, (err, result) ->
    t.same "BASE\nMAIN\nSIDEBAR\n", result
    t.done()

atest "CompAndRender partial", (t) ->
  nct.loadTemplate "{title}", "sub"
  nct.renderTemplate ".> sub", {title: "Hello"}, "t", (err, result, deps) ->
    t.same ["sub"], Object.keys(deps)
    t.same "Hello", result
    t.done()

atest "CompAndRender programmatic partial", (t) ->
  nct.loadTemplate ".> #subtemplate", "t"
  nct.loadTemplate "{title}", "sub"
  nct.render "t", {title: "Hello", subtemplate: 'sub'}, (err, result, deps) ->
    t.same ["sub"], Object.keys(deps)
    t.same "Hello", result
    t.done()

atest "CompAndRender partial recursive", (t) ->
  context = {name: '1', kids: [{name: '1.1', kids: [{name: '1.1.1', kids: []}] }] }
  nct.loadTemplate "{name}\n.# kids\n.> t\n./#", "t"
  nct.render "t", context, (err, result) ->
    t.same "1\n1.1\n1.1.1\n", result
    t.done()

# unless window?
#   atest "Render include", (t) ->
#     include_path = path.join(__dirname, 'fixtures', 'example.txt')
#     nct.loadTemplate ".include #inc", "t"
#     nct.render "t", {inc: include_path}, (err, result) ->
#       t.same "  Hello World\n", result
#       t.done()

atest "Stamp 1", (t) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp", "{stamp}"
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}
  nct.stamp "{stamp}", ctx, (err, fn, deps, stamping) ->
    t.same ctx.posts, stamping
    # info "RESULT", result
    fn stamping[0], (err, result, stamped_name) ->
      t.same "one\n", result
      t.same "1", stamped_name
      t.done()

atest "Stamp from render", (t) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp", "{stamp}"
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}
  nct.render "{stamp}", ctx, (err, result, stamped_name) ->
    t.t -> [err.match(/Stamp called from render/), err]
    t.done()

atest "Stamp 2", (t) ->
  nct.loadTemplate "Hi\n .stamp view posts\n{title}\n./stamp\n", "{year}/{slug}.html"
  e_results = [["2010/first.html","Hi\none\n"],["2011/second.html","Hi\ntwo\n"]]
  ctx =
    view: cbGetFn
    posts: [{title: "one", year: "2010", slug: "first"}, {title: "two", year: "2011", slug: "second"}]
    doit: true

  nct.stamp "{year}/{slug}.html", ctx, (err, render, deps, stamping) ->
    fa.series().map stamping, ((obj, callback) ->
      render obj, (err, result, name, deps) ->
        callback(null, [name,result])
    ), (err, results) ->
      t.same e_results, results
      t.done()

delay = (cb, ctx, params) ->
  setTimeout (() -> cb(null, "")), params[0] || 10

atest "Stamp delays", (t) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp\n{delay}", "{stamp}"
  results = {"1": "one\n","2": "two\n"}
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}], delay: delay}
  nct.stamp "{stamp}", ctx, (err, render, deps, stamping) ->
    render stamping[0], (err, result, name, deps) ->
      t.same "1", name
      t.same results[name], result
      t.done()


atest "Render big list should not be slow", (t) ->
  hours = ({val: i+2, name: "#{i} X"} for i in [1..200])
  nct.loadTemplate "{# hours }{val}:{name}{/#}", "list"
  start = new Date()
  nct.render "list", {hours}, (err, rendered) ->
    t.t ->
      dur = new Date() - start
      [dur < 10, dur]
    # t.t -> [rendered.match(/3:1 X/), rendered]
    # console.timeEnd("list")
    t.done()

unless window? # TODO: make the following tests work in the browser.

  atest "Asynchronous context function", (t) ->
    jsonfile = path.join(__dirname, "fixtures/post.json")
    # fs.writeFileSync jsonfile, JSON.stringify({"title": "Hello World"})
    context =
      content: (callback, context, params) ->
        filename = path.join(__dirname, "fixtures/#{params[0]}.json")
        fs.readFile filename, (err, f) ->
          context.deps[filename] = new Date().getTime()
          callback(null, JSON.parse(f.toString()))

    nct.loadTemplate ".# content post\n{title}\n./#", "t"
    nct.render "t", context, (err, result, deps) ->
      t.same "Hello World\n", result
      t.same [jsonfile], Object.keys(deps)
      t.done()

  contexts =
    'simple': {}
    'example':
      title: 'Hello World'
      post: true
    'page':
      title: "Hello World"
      engine: "nct"

  e_deps =
    'example': []
    'page': ['_base','_footer']

  nct.onLoad = (name, callback) ->
    filename = path.join(__dirname, "fixtures/#{name}.nct")
    fs.readFile filename, (err, f) ->
      callback(null, f.toString(), filename)

  ["example", "page"].forEach (tname) ->
    atest "Integration #{tname}", (t) ->
      fs.readFile path.join(__dirname, "fixtures/#{tname}.nct"), (err, f) ->
        nct.loadTemplate f.toString(), tname
        nct.render tname, contexts[tname], (err, result, deps) ->
          t.same e_deps[tname].map((f) -> path.join(__dirname, "fixtures/#{f}.nct")), Object.keys(deps)
          fs.readFile path.join(__dirname, "fixtures/#{tname}.txt"), (err, f) ->
            t.same(f.toString(), result)
            t.done()

  ["example", "page"].forEach (tname) ->
    atest "Integration #{tname} without load", (t) ->
      nct.removeTemplate tname
      nct.render tname, contexts[tname], (err, result, deps) ->
        t.same e_deps[tname].map((f) -> path.join(__dirname, "fixtures/#{f}.nct")), Object.keys(deps)
        fs.readFile path.join(__dirname, "fixtures/#{tname}.txt"), (err, f) ->
          t.same(f.toString(), result)
          t.done()

  atest "Integration stamp", (t) ->
    context =
      posts: [
        {title: "First Post", slug: "first"}
        {title: "Second Post", slug: "second"}
      ]
      engine: "nc23"
      asset: (callback, context, params, calledfrom) ->
        context.deps[params[0]] = new Date().getTime()
        callback(null, params[0])

    e_deps = ['_base','_footer'].map (f) -> path.join(__dirname, "fixtures/#{f}.nct")
    nct.stamp "{slug}.html", context, (err, render, deps, stamping) ->
      t.same e_deps, Object.keys(deps)
      fa.forEach stamping, ((obj, callback) ->
        ctx = new nct.Context(context)
        ctx = ctx.push(obj)
        render ctx, (err, result, filename, deps) ->
          t.same ['test.js'], Object.keys(deps)
          fs.readFile path.join(__dirname, "fixtures/#{filename}"), (err, f) ->
            t.same(f.toString(), result)
            callback()
            # t.same deps, Object.keys(nct.deps('{slug}.html'))
      ), (err, results) ->
        t.done()

  atest "Integration stamp outside block", (t) ->
    context =
      posts: [
        {title: "First Post", slug: "first"}
        {title: "Second Post", slug: "second"}
      ]
      engine: "nc23"

    deps = ['_base','_footer'].map (f) -> path.join(__dirname, "fixtures/#{f}.nct")
    fs.readFile path.join(__dirname, "fixtures/{slug}.2.html.nct"), (err, f) ->
      nct.loadTemplate f.toString(), "{slug}.html"
      nct.stamp "{slug}.html", context, (err, render, deps, stamping) ->
        fa.forEach stamping, ((obj, callback) ->
          render obj, (err, result, filename, deps) ->
            fs.readFile path.join(__dirname, "fixtures/#{filename}"), (err, f) ->
              t.same(f.toString(), result)
              callback()
              # t.same deps, Object.keys(nct.deps('{slug}.html'))
        ), (err, results) ->
          t.done()

  atest "Custom context lookups by command", (t) ->
    context =
      view: (cb,ctx,params,calledfrom) ->
        if calledfrom == "stamp"
          cb(null, "query")
        else
          cb(null, [{title: calledfrom, slug: "1"}])

    nct.loadTemplate ".# view\n{title}\n./#", "t"
    nct.render "t", context, (err, result) ->
      t.same "each\n", result

      nct.loadTemplate ".stamp view\n{title}\n./stamp", "{slug}"
      nct.stamp "{slug}", context, (err, render, deps, stamping) ->
        t.same "query", stamping
        render {title: "One", slug: "1"}, (err, result, name, deps) ->
          t.same "One\n", result
          t.same "1", name
          t.done()

  atest "Failing template", (t) ->
    context =
      view: (cb, ctx, params) ->
        array = [{title: "title: #{x}"} for x in [0..100]]
        cb(null, array[0])

    nct.render "failing.html", context, (err, rendered, deps) ->
      t.ok !err
      t.ok rendered.match(/title: 10/)
      t.done()

