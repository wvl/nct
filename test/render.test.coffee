fs = require 'fs'
path = require 'path'
{debug,info} = require('triage')('debug')
nct = require path.join(__dirname, "../lib/nct")

suite "nct tests", {serial: true}

atest "New Context", ->
  ctx = new nct.Context({"title": "hello"}, {})
  ctx.get 'title', [], (err, result) ->
    t.same "hello", result
    t.done()

atest "Context push", ->
  ctx = new nct.Context({"title": "hello"}, {})
  ctx = ctx.push({"post": "Hi"})
  ctx.get 'title', [], (err, result) ->
    t.same "hello", result
    ctx.get 'post', [], (err, result) ->
      t.same 'Hi', result
      t.done()

atest "Async function in context", ->
  fn = (cb) ->
    process.nextTick () -> cb(null, "Hi Async!")
  ctx = new nct.Context({"title": fn}, {})
  ctx.get 'title', [], (err, result) ->
    t.same "Hi Async!", result
    t.done()

atest "Context with synchronous function", ->
  ctx = new nct.Context({"title": () -> "Hello World"}, {})
  ctx.get 'title', [], (err, result) ->
    t.same "Hello World", result
    t.done()


contextAccessors = [
  [["title"], {title: "Hello"}, "Hello"]
  [["post","title"], {post: {title: "Hello"}}, "Hello"]
  [["post","blah"], {post: ["Hello"]}, undefined]
  [["post","blah", "blah"], {post: ["Hello"]}, undefined]
]

contextAccessors.forEach ([attrs, context, expected]) ->
  atest "Context accessors #{attrs}", ->
    ctx = new nct.Context(context, {})
    ctx.mget attrs, [], (err, result) ->
      t.same expected, result
      t.done()


cbGetFn = (cb, ctx, params) -> ctx.get(params[0], [], cb)

compileAndRenders = [
  ["Hello", {}, "Hello"]
  ["Hello {title}", {title: "World!"}, "Hello World!"]
  ["Hello {person.name}", {person: {name: "Joe"}}, "Hello Joe"]
  ["Hello {content name}", {content: cbGetFn, name: 'Joe'}, "Hello Joe"]
  [".if content post\n{post.title}\n./if", {content: cbGetFn, post: {title: 'Hello'}}, "Hello\n"]
  [".# content post\n{title}\n./#", {content: cbGetFn, post: {title: 'Hello'}}, "Hello\n"]
  [".if doit\n{name}\n./if", {doit: true, name: "Joe"}, "Joe\n"]
  [".if nope\n{name}\n./if", {nope: false, name: "Joe"}, ""]
  [".if doit\n{name}\n.else\nNoope\n./if", {doit: false, name: "Joe"}, "Noope\n"]
  [".# posts\n{title}\n./#", {posts: [{'title': 'Hello'},{'title':'World'}]}, "Hello\nWorld\n"]
  [".# person\n{name}\n./#", {person: {'name': 'Joe'}}, "Joe\n"]
]

compileAndRenders.forEach ([tmpl,ctx,toequal]) ->
  atest "CompAndRender #{tmpl.replace(/\n/g,' | ')}", ->
    nct.loadTemplate tmpl, "t"
    nct.render "t", ctx, (err, result) ->
      t.same toequal, result
      t.done()

atest "CompAndRender extends", ->
  nct.loadTemplate ".extends base\nHello\n.block main\nt\n./block", "t"
  nct.loadTemplate "Base\n.block main\nBase\n./block", "base"
  nct.render "t", {}, (err, result) ->
    t.same ["base"], Object.keys(nct.deps("t"))
    t.same "Base\nt\n", result
    t.done()

atest "CompAndRender extends 3 levels", ->
  nct.loadTemplate ".extends med\nHello\n.block main\nMAIN\n./block", "t"
  nct.loadTemplate ".extends base\n.block sidebar\nSIDEBAR\n./block", "med"
  nct.loadTemplate "BASE\n.block main\nBASEMAIN\n./block\n.block sidebar\nsidebar base\n./block", "base"
  nct.render "t", {}, (err, result) ->
    t.same "BASE\nMAIN\nSIDEBAR\n", result
    t.done()

atest "CompAndRender include", ->
  nct.loadTemplate ".> sub", "t"
  nct.loadTemplate "{title}", "sub"
  nct.render "t", {title: "Hello"}, (err, result) ->
    t.same ["sub"], Object.keys(nct.deps("t"))
    t.same "Hello", result
    t.done()

atest "CompAndRender include recursive", ->
  context = {name: '1', kids: [{name: '1.1', kids: [{name: '1.1.1', kids: []}] }] }
  nct.loadTemplate "{name}\n.# kids\n.> t\n./#", "t"
  nct.render "t", context, (err, result) ->
    t.same "1\n1.1\n1.1.1\n", result
    t.done()

atest "Stamp 1", ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp", "{stamp}"
  i = 0
  results = [["one\n", "1"],["two\n", "2"]]
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}
  nct.render "{stamp}", ctx, (err, result, stamped_name, finished) ->
    t.same results[i][0], result
    t.same results[i][1], stamped_name
    i++
    if finished
      t.same 2, i
      t.done()

test "Stamp 2", ->
  nct.loadTemplate "Hi\n .stamp view posts\n{title}\n./stamp\n", "{year}/{slug}.html"
  i = 0
  results = {"2010/first.html":  "Hi\none\n", "2011/second.html": "Hi\ntwo\n"}
  ctx =
    view: cbGetFn
    posts: [{title: "one", year: "2010", slug: "first"}, {title: "two", year: "2011", slug: "second"}]
    doit: true

  nct.render "{year}/{slug}.html", ctx, (err, result, stamped_name, finished) ->
    t.same results[stamped_name], result
    i++
    if finished
      t.same 2, i
      t.done()

delay = (cb, ctx, params) ->
  setTimeout (() -> cb(null, "")), params[0] || 10

atest "Stamp delays", ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp\n{delay}", "{stamp}"
  i = 0
  results = {"1": "one\n","2": "two\n"}
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}], delay: delay}
  nct.render "{stamp}", ctx, (err, result, stamped_name, finished) ->
    t.same results[stamped_name], result
    i++
    if finished
      t.same 2, i
      t.done()

atest "Asynchronous context function", ->
  jsonfile = path.join(__dirname, "fixtures/post.json")
  # fs.writeFileSync jsonfile, JSON.stringify({"title": "Hello World"})
  context =
    content: (callback, context, params) ->
      filename = path.join(__dirname, "fixtures/#{params[0]}.json")
      fs.readFile filename, (err, f) ->
        context.deps[filename] = new Date().getTime()
        callback(null, JSON.parse(f.toString()))

  nct.loadTemplate ".# content post\n{title}\n./#", "t"
  nct.render "t", context, (err, result) ->
    t.same "Hello World\n", result
    t.same [jsonfile], Object.keys(nct.deps("t"))
    t.done()

contexts =
  'simple': {}
  'example':
    title: 'Hello World'
    post: true
  'page':
    title: "Hello World"
    engine: "nct"

deps =
  'example': []
  'page': ['_base','_footer']

nct.onLoad = (name, callback) ->
  filename = path.join(__dirname, "fixtures/#{name}.nct")
  fs.readFile filename, (err, f) ->
    callback(null, f.toString(), filename)

["example", "page"].forEach (tname) ->
  atest "Integration #{tname}", ->
    fs.readFile path.join(__dirname, "fixtures/#{tname}.nct"), (err, f) ->
      nct.loadTemplate f.toString(), tname
      nct.render tname, contexts[tname], (err, result, filename, finished) ->
        t.same tname, filename
        t.same finished, true
        fs.readFile path.join(__dirname, "fixtures/#{tname}.txt"), (err, f) ->
          t.same(f.toString(), result)
          t.same deps[tname].map((f) -> path.join(__dirname, "fixtures/#{f}.nct")), 
            Object.keys(nct.deps(tname))
          t.done()

atest "Integration stamp", ->
  context =
    posts: [
      {title: "First Post", slug: "first"}
      {title: "Second Post", slug: "second"}
    ]
  deps = ['_base','_footer'].map (f) -> path.join(__dirname, "fixtures/#{f}.nct")
  fs.readFile path.join(__dirname, "fixtures/{slug}.html.nct"), (err, f) ->
    nct.loadTemplate f.toString(), "{slug}.html" 
    nct.render "{slug}.html", context, (err, result, filename, finished) ->
      fs.readFile path.join(__dirname, "fixtures/#{filename}"), (err, f) ->
        t.same(f.toString(), result)
        t.same deps, Object.keys(nct.deps('{slug}.html'))
        t.done() if finished

atest "Stamp dependency checking", ->
  context =
    view: (cb,ctx,params,calledfrom) ->
      if ctx.deps["view"]
        cb(null, [{title: calledfrom, slug: "1"}])
      else
        ctx.deps["view"] = new Date().getTime()
        cb(null, [{title: "One", slug: "1"}])

  nct.loadTemplate ".# view\n{title}\n./#", "t"
  nct.render "t", context, (err, result) ->
    t.same "One\n", result
    nct.render "t", context, (err, result) ->
      t.same "each\n", result

      nct.loadTemplate ".stamp view\n{title}\n./stamp", "{slug}"
      nct.render "{slug}", context, (err, result) ->
        t.same "One\n", result
        nct.render "{slug}", context, (err, result) ->
          t.same "stamp\n", result
          t.done()
