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


for name,attrs of renderTests
  do (name, attrs) ->
    module.exports["render: #{name}"] = (test) ->
      nct.register "t", attrs[0]
      nct.render "t", attrs[1], (err, result) ->
        test.same attrs[2], result
        test.done()
