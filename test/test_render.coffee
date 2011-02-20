{debug,info} = require('triage')('debug')
nct = require "../lib/nct"

module.exports =
  "New Context": (test) ->
    ctx = new nct.Context({"title": "hello"})
    ctx.get 'title', (err, result) ->
      test.same "hello", result
      test.done()

  "Context push": (test) ->
    ctx = new nct.Context({"title": "hello"})
    ctx = ctx.push({"post": "Hi"})
    ctx.get 'title', (err, result) ->
      test.same "hello", result
      ctx.get 'post', (err, result) ->
        test.same 'Hi', result
        test.done()

  "Async function in context": (test) ->
    fn = (cb) ->
      process.nextTick () -> cb(null, "Hi Async!")
    ctx = new nct.Context({"title": fn})
    ctx.get 'title', (err, result) ->
      test.same "Hi Async!", result
      test.done()

renderTests =
  "Write": ["write('hello')", {}, "hello"]
  "Get": ["get('title')", {'title': 'Hello World'}, "Hello World"]
  "If": ["doif('newuser', write('welcome'))", {'newuser': true}, "welcome"]
  "If false": ["doif('newuser', write('welcome'))", {'newuser': false}, ""]
  "If/Else": ["doif('newuser', write('welcome'), get('name'))",
    {'newuser': false, 'name': 'joe'}, "joe"]
  "Multi": ["multi(write('hello '), get('name'))", {name: 'World'}, "hello World"]
  "Multi 1": ["multi(write('hello '))", {name: 'World'}, "hello "]
  "If Multi": ['''
doif('newuser', multi(get('greeting'),write('new user\\n')))
''',
    {'newuser': true, 'greeting': 'Hello '}, "Hello new user\n"]
  "Each": ["each('post', get('title'))", {'post': [{title: 'Hello'}, {title: 'World'}]}, "HelloWorld"]

for name,attrs of renderTests
  do (name, attrs) ->
    module.exports["render: #{name}"] = (test) ->
      nct.register "t", attrs[0]
      nct.render "t", attrs[1], (err, result) ->
        test.same attrs[2], result
        test.done()

tokenizeTests = [
  ["hello", [['text', 'hello']]],
  ["{title}", [['vararg', 'title']]]
  [".if title", [['if', 'title']]]
  [".if title\n/if", [['if', 'title'], ['endif', null]]]
  ["  .if title\n  /if title\n", [['if', 'title'], ['endif', null]]]
  [".if title\n{title}\n/if title\n", [['if', 'title'], ['vararg','title'], ['text','\n'], ['endif', null]]]
]

tokenizeTests.forEach ([str, tokens]) ->
  module.exports["tokenize: #{str.replace(/\n/g,' | ')}"] = (test) ->
    test.same(tokens, nct.tokenize(str))
    test.done()

compileTests = [
  ["{title}", "get('title')"]
  ["hello {title}", "multi(write('hello '),get('title'))"]
  [".if title\n{title}\n/if", "doif('title', multi(get('title'),write('\\n')))"]
]
compileTests.forEach ([tmpl, compiled]) ->
  module.exports["compile: #{tmpl.replace(/\n/g, ' | ')}"] = (test) ->
    test.same(compiled, nct.compile(tmpl))
    test.done()


compileAndRenderTests = [
  ["Hello", {}, "Hello"]
  ["Hello {title}", {title: "World!"}, "Hello World!"]
  [".if doit\n{name}\n/if", {doit: true, name: "Joe"}, "Joe\n"]
]

compileAndRenderTests.forEach ([tmpl,ctx,toequal]) ->
  module.exports["CompAndRender #{tmpl.replace(/\n/g,' | ')}"] = (test) ->
    nct.loadTemplate tmpl, "t"
    nct.render "t", ctx, (err, result) ->
      test.same toequal, result
      test.done()
