fs = require 'fs'
path = require 'path'
{debug,info} = require('triage') #('debug')
nct = require "../lib/nct"

tests =
  "New Context": (test) ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx.get 'title', (err, result) ->
      test.same "hello", result
      test.done()

  "Context push": (test) ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx = ctx.push({"post": "Hi"})
    ctx.get 'title', (err, result) ->
      test.same "hello", result
      ctx.get 'post', (err, result) ->
        test.same 'Hi', result
        test.done()

  "Async function in context": (test) ->
    fn = (cb) ->
      process.nextTick () -> cb(null, "Hi Async!")
    ctx = new nct.Context({"title": fn}, {})
    ctx.get 'title', (err, result) ->
      test.same "Hi Async!", result
      test.done()

  # "Dotted accessors": (test) ->
  #   ctx = new nct.Context({"post": {title: "Hello World"}}, {})
  #   ctx.get "post.title", (err, result) ->
  #     test.same "Hello World", result
  #     test.done()

renderTests =
  "Write": ["write('hello')", {}, "hello"]
  "Get": ["get('title')", {'title': 'Hello World'}, "Hello World"]
  "If": ["doif('newuser', write('welcome'))", {'newuser': true}, "welcome"]
  "If false": ["doif('newuser', write('welcome'))", {'newuser': false}, ""]
  "If/Else": ["doif('newuser', write('welcome'), get('name'))",
    {'newuser': false, 'name': 'joe'}, "joe"]
  "Multi": ["multi([write('hello '), get('name')])", {name: 'World'}, "hello World"]
  "Multi 1": ["multi([write('hello ')])", {name: 'World'}, "hello "]
  "If Multi": ['''doif('newuser', multi([get('greeting'),write('new user\\n')]))''',
    {'newuser': true, 'greeting': 'Hello '}, "Hello new user\n"]
  "Each": ["each('post', get('title'))", {'post': [{title: 'Hello'}, {title: 'World'}]}, "HelloWorld"]
  "Each object": ["each('person', get('name'))", {'person': {name: 'Joe'}}, "Joe"]

for name,attrs of renderTests
  do (name, attrs) ->
    tests["render: #{name}"] = (test) ->
      nct.register "t", attrs[0]
      nct.render "t", attrs[1], (err, result) ->
        test.same attrs[2], result
        test.done()

tests["render: extends"] = (test) ->
  nct.register "edge", "extend('base', block('main', multi([get('title')])))"
  nct.register "base", "multi([write('base + '),block('main', multi([write('base')]))])"
  nct.render "edge", {title: "Hello"}, (err, result) ->
    test.same "base + Hello", result
    test.done()

tests["render: extends 3 levels"] = (test) ->
  nct.register "edge", "extend('t', multi([write('Blah')]))"
  nct.register "t", "extend('base', block('main', multi([get('title')])))"
  nct.register "base", "multi([write('base + '),block('main', write('base'))])"
  nct.render "edge", {title: "Hello"}, (err, result) ->
    test.same "base + Hello", result
    test.done()

tokenizeTests = [
  ["hello", [['text', 'hello']]],
  ["{title}", [['vararg', 'title']]]
  [".if title", [['if', 'title']]]
  [".if title\n./if", [['if', 'title'], ['endif', null]]]
  ["  .if title\n  ./if title\n", [['if', 'title'], ['endif', null]]]
  [".if title\n{title}\n./if title\n", [['if', 'title'], ['vararg','title'], ['text','\n'], ['endif', null]]]
  [".extends base\n.block main\n./block", [['extends', 'base'], ['block', 'main'], ['endblock',null]]]
]

tokenizeTests.forEach ([str, tokens]) ->
  tests["tokenize: #{str.replace(/\n/g,' | ')}"] = (test) ->
    test.same(tokens, nct.tokenize(str))
    test.done()

compileTests = [
  ["{title}", "get('title')"]
  ["hello {title}", "multi([write('hello '),get('title')])"]
  [".if title\n{title}\n./if", "doif('title', multi([get('title'),write('\\n')]))"]
]
compileTests.forEach ([tmpl, compiled]) ->
  tests["compile: #{tmpl.replace(/\n/g, ' | ')}"] = (test) ->
    test.same(compiled, nct.compile(tmpl))
    test.done()


compileAndRenderTests = [
  ["Hello", {}, "Hello"]
  ["Hello {title}", {title: "World!"}, "Hello World!"]
  [".if doit\n{name}\n./if", {doit: true, name: "Joe"}, "Joe\n"]
  [".if doit\n{name}\n.else\nNoope\n./if", {doit: false, name: "Joe"}, "Noope\n"]
  [".# posts\n{title}\n./#", {posts: [{'title': 'Hello'},{'title':'World'}]}, "Hello\nWorld\n"]
  [".# posts\n{title}\n./#", {posts: [{'title': 'Hello'},{'title':'World'}]}, "Hello\nWorld\n"]
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

tests["Stamp 1"] = (test) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp", "{stamp}"
  i = 0
  results = [["one\n", "1"],["two\n", "2"]]
  nct.render "{stamp}", {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}, (err, result) ->
    test.same results[i], result
    test.done() if ++i==2

tests["Stamp 2"] = (test) ->
  nct.loadTemplate ".stamp posts\n{title}\n./stamp", "{year}/{slug}.html"
  i = 0
  results = [["one\n", "2010/first.html"],["two\n", "2011/second.html"]]
  ctx =
    posts: [{title: "one", year: "2010", slug: "first"}, {title: "two", year: "2011", slug: "second"}]
  nct.render "{year}/{slug}.html", ctx, (err, result) ->
    test.same results[i], result
    test.done() if ++i==2

# tests["Asynchronous context function"] = (test) ->
#   context =
#     content: (name, callback) ->
#       filename = path.join(__dirname, "fixtures/#{name}.json")
#       fs.readFile filename, (err, f) ->
#         callback(null, JSON.parse(f.toString()))
#   nct.loadTemplate ".# content:mypost "

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
  debug "onLoad called: #{name}"
  fs.readFile path.join(__dirname, "fixtures/#{name}.nct"), (err, f) ->
    callback(null, f.toString())

["example", "page"].forEach (testname) ->
  tests["Integration #{testname}"] = (test) ->
    fs.readFile path.join(__dirname, "fixtures/#{testname}.nct"), (err, f) ->
      nct.loadTemplate f.toString(), testname
      fs.readFile path.join(__dirname, "fixtures/#{testname}.json"), (err, f) ->
        nct.render testname, contexts[testname], (err, result) ->
          fs.readFile path.join(__dirname, "fixtures/#{testname}.txt"), (err, f) ->
            test.same(f.toString(), result)
            test.same deps[testname], nct.deps(testname)
            test.done()

module.exports = tests
