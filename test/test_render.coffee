{debug,info} = require('triage')('debug')
nct = require "../lib/nct"

renderTests =
  "Write": ["write('hello')", {}, "hello"]
  "Get": ["get('title')", {'title': 'Hello World'}, "Hello World"]
  "If": ["doif('newuser', write('welcome'))", {'newuser': true}, "welcome"]
  "If false": ["doif('newuser', write('welcome'))", {'newuser': false}, ""]
  "If/Else": ["doif('newuser', write('welcome'), get('name'))", 
    {'newuser': false, 'name': 'joe'}, "joe"]
  "Multi": ["multi(write('hello '), get('name'))", {name: 'World'}, "hello World"]
  "Multi 1": ["multi(write('hello '))", {name: 'World'}, "hello "]
  "Each": ["each('post', get('title'))", {'post': [{title: 'Hello'}, {title: 'World'}]}, "HelloWorld"]

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

for name,attrs of renderTests
  do (name, attrs) ->
    module.exports["render: #{name}"] = (test) ->
      nct.register "t", attrs[0]
      nct.render "t", attrs[1], (err, result) ->
        test.same attrs[2], result
        test.done()
