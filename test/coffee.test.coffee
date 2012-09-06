
coffee = require '../lib/coffee'
e = require('chai').expect
nct = require '../lib/nct'
fs = require 'fs'

cc = (fn, ctx={}, dir) ->
  tmpl = coffee.compile(fn, dir)
  fn = nct.loadTemplate(tmpl)
  fn(new nct.Context(ctx))


describe "Test Coffeescript Precompiler", ->
  it "should output a div as a string from string", ->
    e(cc("div('hello')")).to.equal '<div>hello</div>'

  it "should output a div as a string from function", ->
    e(cc(-> div 'hello')).to.equal '<div>hello</div>'

  it "should compile to nct template", ->
    e(cc((-> div -> ctx('msg')), {msg: 'hi'})).to.equal '<div>hi</div>'

  it "should output element's id", ->
    e(cc(-> div '#myid', "hello")).to.equal '<div id="myid">hello</div>'

  it "should support classes", ->
    e(cc(-> div '.test', "hi")).to.equal '<div class="test">hi</div>'
    e(cc(-> div '.test.two', "hi")).to.equal '<div class="test two">hi</div>'
  it "should support ids and classes", ->
    e(cc(-> div '#myid.test.two', "hi")).to.equal '<div id="myid" class="test two">hi</div>'

  it "should render attrs provided as object", ->
    e(cc(-> div {name: 'joe'})).to.equal '<div name="joe"></div>'

  it "should render attrs provided as object", ->
    e(cc(-> div {data: {name: 'joe'}})).to.equal '<div data-name="joe"></div>'

  it "should render nested tags", ->
    e(cc(-> div -> span "Hello")).to.equal '<div><span>Hello</span></div>'

  # it "should output the result of a function inside a tag", ->
  #   e(cc(-> div -> "hello")).to.equal '<div>hello</div>'

  it "should render if statements in template", ->
    e(cc(-> $if 'name', -> div 'yes')).to.equal ''
    result = cc((-> $if 'name', -> div 'yes'),{name: true})
    e(result).to.equal '<div>yes</div>'

  it "should render if/else statements in template", ->
    e(cc(-> $if 'name', (-> div 'yes'), (-> div 'no'))).to.equal '<div>no</div>'

  it "should render unless statements in template", ->
    tmpl = -> $unless 'name', (-> div 'no')
    e(cc(tmpl, {name: true})).to.equal ''
    e(cc(tmpl, {name: false})).to.equal '<div>no</div>'

  it "should render loops", ->
    tmpl = -> $each 'people', -> li -> ctx('name')
    result = cc(tmpl, {people: [{name: 'joe'}, {name: 'jane'}]})
    e(result).to.equal '<li>joe</li><li>jane</li>'

  it "should render self closing elements", ->
    e(cc(-> hr())).to.equal '<hr/>'

  it "should render doctype", ->
    e(cc(-> doctype('5'))).to.equal '<!DOCTYPE html>'

  it "should output text", ->
    e(cc(-> text "hello")).to.equal 'hello'

  it "should work with helper functions", ->
    tmpl = ->
      helper = (name) -> div name
      helper('me')
    e(cc(tmpl)).to.equal '<div>me</div>'

  it "should ouptut ctx functions directly with @prefix", ->
    e(cc((-> div '@msg'), {msg: 'hi'})).to.equal "<div>hi</div>"

  it "should parse @ out of keys and values", ->
    tmpl = -> div {k1: '@v1', '@k2': 'v2'}, '@msg'
    r = cc(tmpl,{v1:'value1',k2:'key2',msg:'Hi'})
    e(r).to.equal '<div k1="value1" key2="v2">Hi</div>'

  it "should support context based class name with '.' accessor", ->
    tmpl = -> div '.@test', -> span '.something.@error:username', ''
    r = cc(tmpl, {test: 'one', error: {username: 'oops'}})
    e(r).to.equal '<div class="one"><span class="something oops"></span></div>'

  it "should allow multiple statements in a block", ->
    tmpl = -> div ->
      a {href: '/'}, 'link'
      text ' or '
      a {href: '/back'}, 'cancel'
    e(cc(tmpl)).to.equal '<div><a href="/">link</a> or <a href="/back">cancel</a></div>'

  it "should allow class definition with object", ->
    tmpl = -> div {class: 'test'}, 'Hello'
    e(cc(tmpl)).to.equal '<div class="test">Hello</div>'

  # it "should allow multiple types of class definitions", ->
  #   tmpl = -> div '.one', {class: 'two'}, 'Hello'
  #   e(cc(tmpl)).to.equal '<div class="one two">Hello</div>'

  # it "should allow requiring other files", ->
  #   dir = __dirname+'/fixtures'
  #   tmpl = fs.readFileSync(dir+'/signup.ncc', 'utf8')
  #   result = cc(tmpl,dir)
  #   # console.log("result: ", result)

