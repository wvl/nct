fs = require 'fs'
path = require 'path'
{debug,info} = require('triage') #('debug')
nct = require "../lib/nct"

tests =
  "New Context": (test) ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx.get 'title', [], (err, result) ->
      test.same "hello", result
      test.done()

  "Context push": (test) ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx = ctx.push({"post": "Hi"})
    ctx.get 'title', [], (err, result) ->
      test.same "hello", result
      ctx.get 'post', [], (err, result) ->
        test.same 'Hi', result
        test.done()

  "Async function in context": (test) ->
    fn = (cb) ->
      process.nextTick () -> cb(null, "Hi Async!")
    ctx = new nct.Context({"title": fn}, {})
    ctx.get 'title', [], (err, result) ->
      test.same "Hi Async!", result
      test.done()


contextAccessors = [
  [["title"], {title: "Hello"}, "Hello"]
  [["post","title"], {post: {title: "Hello"}}, "Hello"]
  [["post","blah"], {post: ["Hello"]}, undefined]
  [["post","blah", "blah"], {post: ["Hello"]}, undefined]
]

contextAccessors.forEach ([attrs, context, expected]) ->
  tests["Context accessors #{attrs}"] = (test) ->
    ctx = new nct.Context(context, {})
    ctx.mget attrs, [], (err, result) ->
      test.same expected, result
      test.done()


cbGetFn = (cb, ctx, params) -> ctx.get(params[0], cb)

compileAndRenderTests = [
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

compileAndRenderTests.forEach ([tmpl,ctx,toequal]) ->
  tests["CompAndRender #{tmpl.replace(/\n/g,' | ')}"] = (test) ->
    nct.loadTemplate tmpl, "t"
    nct.render "t", ctx, (err, result) ->
      test.same toequal, result
      test.done()

tests["CompAndRender extends"] = (test) ->
  nct.loadTemplate ".extends base\nHello\n.block main\nt\n./block", "t"
  nct.loadTemplate "Base\n.block main\nBase\n./block", "base"
  nct.render "t", {}, (err, result) ->
    test.same ["base"], nct.deps("t")
    test.same "Base\nt\n", result
    test.done()

tests["CompAndRender include"] = (test) ->
  nct.loadTemplate ".> sub", "t"
  nct.loadTemplate "{title}", "sub"
  nct.render "t", {title: "Hello"}, (err, result) ->
    test.same ["sub"], nct.deps("t")
    test.same "Hello", result
    test.done()

tests["CompAndRender include recursive"] = (test) ->
  context = {name: '1', kids: [{name: '1.1', kids: [{name: '1.1.1', kids: []}] }] }
  nct.loadTemplate "{name}\n.# kids\n.> t\n./#", "t"
  nct.render "t", context, (err, result) ->
    test.same "1\n1.1\n1.1.1\n", result
    test.done()

tests["Stamp 1"] = (test) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp", "{stamp}"
  i = 0
  results = [["one\n", "1"],["two\n", "2"]]
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}
  nct.render "{stamp}", ctx, (err, result, stamped_name, finished) ->
    test.same results[i][0], result
    test.same results[i][1], stamped_name
    i++
    if finished
      test.same 2, i
      test.done()

tests["Stamp 2"] = (test) ->
  nct.loadTemplate "Hi\n .stamp view posts\n{title}\n./stamp\n", "{year}/{slug}.html"
  i = 0
  results = {"2010/first.html":  "Hi\none\n", "2011/second.html": "Hi\ntwo\n"}
  ctx =
    view: cbGetFn
    posts: [{title: "one", year: "2010", slug: "first"}, {title: "two", year: "2011", slug: "second"}]
    doit: true

  nct.render "{year}/{slug}.html", ctx, (err, result, stamped_name, finished) ->
    test.same results[stamped_name], result
    i++
    if finished
      test.same 2, i
      test.done()

delay = (cb, ctx, params) ->
  setTimeout (() -> cb(null, "")), params[0] || 10

tests["Stamp delays"] = (test) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp\n{delay}", "{stamp}"
  i = 0
  results = {"1": "one\n","2": "two\n"}
  ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}], delay: delay}
  nct.render "{stamp}", ctx, (err, result, stamped_name, finished) ->
    test.same results[stamped_name], result
    i++
    if finished
      test.same 2, i
      test.done()

tests["Asynchronous context function"] = (test) ->
  jsonfile = path.join(__dirname, "fixtures/post.json")
  # fs.writeFileSync jsonfile, JSON.stringify({"title": "Hello World"})
  context =
    content: (callback, context, params) ->
      filename = path.join(__dirname, "fixtures/#{params[0]}.json")
      fs.readFile filename, (err, f) ->
        context.deps.push(filename)
        callback(null, JSON.parse(f.toString()))

  nct.loadTemplate ".# content post\n{title}\n./#", "t"
  nct.render "t", context, (err, result) ->
    test.same "Hello World\n", result
    test.same [jsonfile], nct.deps("t")
    test.done()

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
  fs.readFile path.join(__dirname, "fixtures/#{name}.nct"), (err, f) ->
    callback(null, f.toString())

["example", "page"].forEach (testname) ->
  tests["Integration #{testname}"] = (test) ->
    fs.readFile path.join(__dirname, "fixtures/#{testname}.nct"), (err, f) ->
      nct.loadTemplate f.toString(), testname
      nct.render testname, contexts[testname], (err, result) ->
        fs.readFile path.join(__dirname, "fixtures/#{testname}.txt"), (err, f) ->
          test.same(f.toString(), result)
          test.same deps[testname], nct.deps(testname)
          test.done()

tests["Integration stamp"] = (test) ->
  context =
    posts: [
      {title: "First Post", slug: "first"}
      {title: "Second Post", slug: "second"}
    ]
  fs.readFile path.join(__dirname, "fixtures/{slug}.html.nct"), (err, f) ->
    nct.loadTemplate f.toString(), "{slug}.html" 
    nct.render "{slug}.html", context, (err, result, filename, finished) ->
      fs.readFile path.join(__dirname, "fixtures/#{filename}"), (err, f) ->
        test.same(f.toString(), result)
        # test.same deps[testname], nct.deps(testname)
        test.done() if finished

module.exports = tests
