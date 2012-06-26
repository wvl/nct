if !window?
  fs = require 'fs'
  path = require 'path'
  fa = require 'fa'
  nct = require('../lib/nct').sync
  _ = require 'underscore'
  e = require('chai').expect
  global.nct = nct  # using precompiled templates requires a global
  require './fixtures/templates'
else
  window.e = chai.expect


describe "Sync Context", ->
  it "New Context", ->
    ctx = new nct.Context({"title": "hello"}, {})
    e(ctx.get('title')).to.equal "hello"

  it "Context push", ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx = ctx.push({"post": "Hi"})
    e(ctx.get('title')).to.equal "hello"
    e(ctx.get('post')).to.equal "Hi"

  it "Context with synchronous function", ->
    ctx = new nct.Context({"title": () -> "Hello World"}, {})
    e(ctx.get('title')).to.equal "Hello World"

  it "Context.get from null", ->
    ctx = new nct.Context(null)
    e(ctx.get('title')).to.equal ""

  contextAccessors = [
    [["title"], {title: "Hello"}, "Hello"]
    [["post","title"], {post: {title: "Hello"}}, "Hello"]
    [["post","blah"], {post: ["Hello"]}, undefined]
    [["post","blah","blah"], {post: ["Hello"]}, ""]
    [["post","isnull","blah"], {post: null}, null]
  ]

  contextAccessors.forEach ([attrs, context, expected]) ->
    it "Context accessors #{attrs}", ->
      ctx = new nct.Context(context, {})
      e(ctx.mget(attrs)).to.equal expected


getFn = (ctx, params) ->
  ctx.get(params[0], [])

describe "Sync Compile and Render", ->
  nct.filters.upcase = (v) -> v.toUpperCase()
  nct.filters.question = (v) -> v+'?'


  compileAndRenders = [
    ["Hello", {}, "Hello"]
    ["Hello {title}", {title: "World!"}, "Hello World!"]
    ["Hello { title }", {title: "World!"}, "Hello World!"]
    ["Hello {person.name}", {person: {name: "Joe"}}, "Hello Joe"]
    ["Hello {person.name}", {person: (-> {name: "Joe"})}, "Hello Joe"]
    ["Hello {person.name}", {person: {name: "<i>Joe</i>"}}, "Hello &lt;i&gt;Joe&lt;/i&gt;"]
    ["Hello {person.name}", {person: (-> {name: (-> "Joe")})}, "Hello Joe"]
    ["Hello {content name}", {content: getFn, name: 'Joe'}, "Hello Joe"]
    ["Hello {content.get name}", {content: {get: getFn}, name: 'Joe'}, "Hello Joe"]
    ["{if post}{post.title}{/if}", {post: {title: 'Hello'}}, "Hello"]
    ["{# post}{title}{/#}", {post: {title: 'Hello'}}, "Hello"]
    ["{if doit}{name}{/if}", {doit: true, name: "Joe"}, "Joe"]
    ["{if nope}{name}{/if}", {nope: false, name: "Joe"}, ""]
    ["{if doit}{name}{else}Noope{/if}", {doit: false, name: "Joe"}, "Noope"]
    ["{if array}NotEmpty{else}Empty{/if}", {array: []}, "Empty"]
    ["{# posts}{title}{/#}", {posts: [{'title': 'Hello'},{'title':'World'}]}, "HelloWorld"]
    ["{# person}{name}{/#}", {person: {'name': 'Joe'}}, "Joe"]
    ["{# person}{/#}", {person: {'name': 'Joe'}}, ""]
    ["{# person}{else}Nope{/#}", {person: []}, "Nope"]
    ["{if post}{post.title}{/if}", {post: {title: 'Hello'}}, "Hello"]
    ["{# person}{name}{/# person}", {person: {'name': 'Joe'}}, "Joe"]
    ["{- noescape }", {noescape: "<h1>Hello</h1>"}, "<h1>Hello</h1>"]
    ["{- post.title}", {post: {title: "<h1>Hello</h1>"}}, "<h1>Hello</h1>"]
    ["{ title | upcase}", {title: 'hello world'}, "HELLO WORLD"]
    ["{ title | upcase | question}", {title: 'hello'}, "HELLO?"]
    ["{ escape }", {escape: "<h1>Hello</h1>"}, "&lt;h1&gt;Hello&lt;/h1&gt;"]
    ["{no}{hello}{/no}", {}, "{hello}"]
    ["{if msg}{notemplate}{hello}{/notemplate}{/if}", {msg: true}, "{hello}"]
    ["{if msg}{no}{hello}{/no}{/if}", {msg: false}, ""]
    ["<script>{no}\nnew Something({});\n{/no}</script>", {}, "<script>\nnew Something({});\n</script>"]
    ["{# tags}{if last},{/if}{n}{/#}", {tags: [{n: '1'}, {n: '2'}]}, "1,2"]
    ["{unless nope}{name}{/unless}", {nope: false, name: "Joe"}, "Joe"]
  ]

  compileAndRenders.forEach ([tmpl,ctx,toequal]) ->
    it "CompAndRender #{nct.escape(tmpl.replace(/\n/g,' | '))}", ->
      e(nct.renderTemplate(tmpl, ctx)).to.equal toequal

  it "CompAndRender partial", ->
    nct.loadTemplate "{title}", "sub"
    result = nct.renderTemplate "{> sub}", {title: "Hello"}, "t"
    e(result).to.equal "Hello"

  it "CompAndRender programmatic partial", ->
    nct.loadTemplate "{> #subtemplate}", "t"
    nct.loadTemplate "{title}", "sub"
    result = nct.render "t", {title: "Hello", subtemplate: 'sub'}
    e(result).to.equal "Hello"

  it "CompAndRender partial recursive", ->
    context = {name: '1', kids: [{name: '1.1', kids: [{name: '1.1.1', kids: []}] }] }
    nct.loadTemplate "{name}\n{# kids}{> t}{/#}", "t"
    result = nct.render "t", context
    e(result).to.equal "1\n1.1\n1.1.1\n"

  it "Render big list should not be slow", ->
    hours = ({val: i+2, name: "#{i} X"} for i in [1..2000])
    nct.loadTemplate "{# hours }{-val}:{-name}{/#}", "list"
    start = new Date()
    result = nct.render "list", {hours}
    dur = new Date() - start
    e(dur).to.be.below 40

describe "Sync Precompiled Sample Template", ->
  it "Should render", ->
    e(nct.templates['sample']).to.exist
    result = nct.render "sample", {}
    e(result).to.match /precompiled/

  it "Should render with data", ->
    d = {post: {title: 'Hello'}, list: [{name: 'Juan'}]}
    result = nct.render "sample", d
    e(result).to.match /precompiled/
    e(result).to.match /\<li\>Juan\<\/li\>/

  it "should render with noescape", ->
    result = nct.render "sample", {noListMsg: '<h1>nope</h1>'}
    e(result).to.match /\<h1\>nope\<\/h1\>/

describe "Sync blocks", ->
  it "should handle basic block", ->
    nct.loadTemplate "Layout: {block main}override{/block}", "layout"
    nct.loadTemplate "{extends layout}{block main}App{/block}", "app"
    result = nct.render "app", {}
    e(result).to.match /Layout: App/

  it "extends 3 levels", ->
    nct.loadTemplate "{extends med}Hello{block main}MAIN\n{/block}", "t"
    nct.loadTemplate "{extends base}{block sidebar}SIDEBAR\n{/block}", "med"
    nct.loadTemplate "BASE\n{block main}BASEMAIN{/block}{block sidebar}sidebar base{/block}", "base"
    result = nct.render "t", {}
    e(result).to.equal "BASE\nMAIN\nSIDEBAR\n"
