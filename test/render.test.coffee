if !window?
  fs = require 'fs'
  path = require 'path'
  fa = require 'fa'
  nct = require('../lib/nct').async
  _ = require 'underscore'
  e = require('chai').expect
else
  window.e = chai.expect


describe "Context", ->
  it "New Context", (done) ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx.get 'title', [], (err, result) ->
      e(result).to.equal "hello"
      done()

  it "Context push", (done) ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx = ctx.push({"post": "Hi"})
    ctx.get 'title', [], (err, result) ->
      e(result).to.equal "hello"
      ctx.get 'post', [], (err, result) ->
        e(result).to.equal('Hi')
        done()

  it "Async function in context", (done) ->
    fn = (cb) ->
      process.nextTick () -> cb(null, "Hi Async!")
    ctx = new nct.Context({"title": fn}, {})
    ctx.get 'title', [], (err, result) ->
      e(result).to.equal "Hi Async!"
      done()

  it "Context with synchronous function", (done) ->
    ctx = new nct.Context({"title": () -> "Hello World"}, {})
    ctx.get 'title', [], (err, result) ->
      e(result).to.equal "Hello World"
      done()

  it "Context.get from null", (done) ->
    ctx = new nct.Context(null)
    ctx.get 'title', [], (err, result) ->
      e(result).to.equal null
      done()


  contextAccessors = [
    [["title"], {title: "Hello"}, "Hello"]
    [["post","title"], {post: {title: "Hello"}}, "Hello"]
    [["post","blah"], {post: ["Hello"]}, undefined]
    [["post","blah","blah"], {post: ["Hello"]}, undefined]
    [["post","isnull","blah"], {post: null}, null]
  ]

  contextAccessors.forEach ([attrs, context, expected]) ->
    it "Context accessors #{attrs}", (done) ->
      ctx = new nct.Context(context, {})
      ctx.mget attrs, [], (err, result) ->
        e(result).to.equal expected
        done()


cbGetFn = (cb, ctx, params) -> ctx.get(params[0], [], cb)

describe "Compile and Render", ->

  compileAndRenders = [
    ["Hello", {}, "Hello"]
    ["Hello {title}", {title: "World!"}, "Hello World!"]
    ["Hello { title }", {title: "World!"}, "Hello World!"]
    ["Hello {person.name}", {person: {name: "Joe"}}, "Hello Joe"]
    ["Hello {person.name}", {person: (-> {name: "Joe"})}, "Hello Joe"]
    ["Hello {person.name}", {person: (-> {name: (-> "Joe")})}, "Hello Joe"]
    ["Hello {content name}", {content: cbGetFn, name: 'Joe'}, "Hello Joe"]
    ["{if content post}{post.title}{/if}", {content: cbGetFn, post: {title: 'Hello'}}, "Hello"]
    ["{# content post}{title}{/#}", {content: cbGetFn, post: {title: 'Hello'}}, "Hello"]
    ["{if doit}{name}{/if}", {doit: true, name: "Joe"}, "Joe"]
    ["{if nope}{name}{/if}", {nope: false, name: "Joe"}, ""]
    ["{if doit}{name}{else}Noope{/if}", {doit: false, name: "Joe"}, "Noope"]
    ["{# posts}{title}{/#}", {posts: [{'title': 'Hello'},{'title':'World'}]}, "HelloWorld"]
    ["{# person}{name}{/#}", {person: {'name': 'Joe'}}, "Joe"]
    ["{# person}{/#}", {person: {'name': 'Joe'}}, ""]
    ["{# person}{else}Nope{/#}", {person: []}, "Nope"]

    ["{if content post}{post.title}{/if}", {content: cbGetFn, post: {title: 'Hello'}}, "Hello"]
    ["{# person}{name}{/# person}", {person: {'name': 'Joe'}}, "Joe"]

    ["{ noescape | s }", {noescape: "<h1>Hello</h1>"}, "<h1>Hello</h1>"]
    ["{ blah | s | t | h}", {}, ""]
    ["{ escape }", {escape: "<h1>Hello</h1>"}, "&lt;h1&gt;Hello&lt;/h1&gt;"]

    ["{- noescape}", {noescape: "<h1>Hello</h1>"}, "<h1>Hello</h1>"]
    ["{no}{hello}{/no}", {}, "{hello}"]
    ["{if msg}{no}{hello}{/no}{/if}", {msg: true}, "{hello}"]
    ["{if msg}{no}{hello}{/no}{/if}", {msg: false}, ""]
    ["<script>{no}\nnew Something({});\n{/no}</script>", {}, "<script>\nnew Something({});\n</script>"]
    ["{# tags}{if last},{/if}{n}{/#}", {tags: [{n: '1'}, {n: '2'}]}, "1,2"]
    ["{unless nope}{name}{/unless}", {nope: false, name: "Joe"}, "Joe"]
  ]

  compileAndRenders.forEach ([tmpl,ctx,toequal]) ->
    it "CompAndRender #{nct.escape(tmpl.replace(/\n/g,' | '))}", (done) ->
      nct.renderTemplate tmpl, ctx, (err, result) ->
        e(result).to.equal toequal
        done()

  it "template filter", (done) ->
    nct.renderTemplate "{ body | t }", {body: "{realbody}", realbody: "Hello!"}, (err, result) ->
      e(result).to.equal "Hello!"
      done()

  it "CompAndRender extends", (done) ->
    nct.loadTemplate "{extends base}Hello{block main}t{/block}", "t"
    nct.loadTemplate "Base\n{block main}Base{/block}", "base"
    nct.render "t", {}, (err, result, deps) ->
      e(Object.keys(deps)).to.eql ["base"]
      e(result).to.equal "Base\nt"
      done()

  it "CompAndRender extends 3 levels", (done) ->
    nct.loadTemplate "{extends med}Hello{block main}MAIN\n{/block}", "t"
    nct.loadTemplate "{extends base}{block sidebar}SIDEBAR\n{/block}", "med"
    nct.loadTemplate "BASE\n{block main}BASEMAIN{/block}{block sidebar}sidebar base{/block}", "base"
    nct.render "t", {}, (err, result) ->
      e(result).to.equal "BASE\nMAIN\nSIDEBAR\n"
      done()

  it "CompAndRender partial", (done) ->
    nct.loadTemplate "{title}", "sub"
    nct.renderTemplate "{> sub}", {title: "Hello"}, "t", (err, result, deps) ->
      e(Object.keys(deps)).to.eql ["sub"]
      e(result).to.equal "Hello"
      done()

  it "CompAndRender programmatic partial", (done) ->
    nct.loadTemplate "{> #subtemplate}", "t"
    nct.loadTemplate "{title}", "sub"
    nct.render "t", {title: "Hello", subtemplate: 'sub'}, (err, result, deps) ->
      e(Object.keys(deps)).to.eql ["sub"]
      e(result).to.equal "Hello"
      done()

  it "CompAndRender partial recursive", (done) ->
    context = {name: '1', kids: [{name: '1.1', kids: [{name: '1.1.1', kids: []}] }] }
    nct.loadTemplate "{name}\n{# kids}{> t}{/#}", "t"
    nct.render "t", context, (err, result) ->
      e(result).to.equal "1\n1.1\n1.1.1\n"
      done()


describe "Stamping", ->
  #   it "Render include", (done) ->
  #     include_path = path.join(__dirname, 'fixtures', 'example.txt')
  #     nct.loadTemplate ".include #inc", "t"
  #     nct.render "t", {inc: include_path}, (err, result) ->
  #       t.same "  Hello World\n", result
  #       t.done()

  it "Stamp 1", (done) ->
    nct.loadTemplate "{stamp posts}{title}{/stamp}", "{stamp}"
    ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}
    nct.stamp "{stamp}", ctx, (err, fn, deps, stamping) ->
      e(stamping).to.equal ctx.posts
      # info "RESULT", result
      fn stamping[0], (err, result, stamped_name) ->
        e(result).to.equal "one"
        e(stamped_name).to.equal "1"
        done()

  it "Stamp from render", (done) ->
    nct.loadTemplate "{stamp posts}{title}{/stamp}", "{stamp}"
    ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}]}
    nct.render "{stamp}", ctx, (err, result, stamped_name) ->
      e(err).to.match /Stamp called from render/
      done()

  it "Stamp 2", (done) ->
    nct.loadTemplate "Hi\n{stamp view posts}{title}\n{/stamp}", "{year}/{slug}.html"
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
        e(results).to.eql e_results
        done()

  delay = (cb, ctx, params) ->
    setTimeout (() -> cb(null, "")), params[0] || 10

  it "Stamp delays", (done) ->
    nct.loadTemplate "{stamp posts}{title}\n{/stamp}{delay}", "{stamp}"
    results = {"1": "one\n","2": "two\n"}
    ctx = {posts: [{title: "one", stamp: "1"}, {title: "two", stamp: "2"}], delay: delay}
    nct.stamp "{stamp}", ctx, (err, render, deps, stamping) ->
      render stamping[0], (err, result, name, deps) ->
        e(name).to.equal "1"
        e(result).to.equal results[name]
        done()


  it "Render big list should not be slow", (done) ->
    hours = ({val: i+2, name: "#{i} X"} for i in [1..1000])
    nct.loadTemplate "{# hours }{-val}:{-name}{/#}", "list"
    start = new Date()
    nct.render "list", {hours}, (err, rendered) ->
      dur = new Date() - start
      e(dur).to.be.below 200 # async is slow!
      done()

if not window? # TODO: make the following tests work in the browser.

  describe "integration", ->

    it "Asynchronous context function", (done) ->
      jsonfile = path.join(__dirname, "fixtures/post.json")
      # fs.writeFileSync jsonfile, JSON.stringify({"title": "Hello World"})
      context =
        content: (callback, context, params) ->
          filename = path.join(__dirname, "fixtures/#{params[0]}.json")
          fs.readFile filename, (err, f) ->
            context.deps[filename] = new Date().getTime()
            callback(null, JSON.parse(f.toString()))

      nct.loadTemplate "{# content post}{title}\n{/#}", "t"
      nct.render "t", context, (err, result, deps) ->
        e(result).to.equal "Hello World\n"
        e(Object.keys(deps)).to.eql [jsonfile]
        done()

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
      it "Integration #{tname}", (done) ->
        fs.readFile path.join(__dirname, "fixtures/#{tname}.nct"), (err, f) ->
          nct.loadTemplate f.toString(), tname
          nct.render tname, contexts[tname], (err, result, deps) ->
            e(Object.keys(deps)).to.eql e_deps[tname].map((f) -> path.join(__dirname, "fixtures/#{f}.nct"))
            fs.readFile path.join(__dirname, "fixtures/#{tname}.txt"), (err, f) ->
              e(result).to.equal f.toString()
              done()

    ["example", "page"].forEach (tname) ->
      it "Integration #{tname} without load", (done) ->
        nct.removeTemplate tname
        nct.render tname, contexts[tname], (err, result, deps) ->
          e(Object.keys(deps)).to.eql e_deps[tname].map((f) -> path.join(__dirname, "fixtures/#{f}.nct"))
          fs.readFile path.join(__dirname, "fixtures/#{tname}.txt"), (err, f) ->
            e(result).to.equal f.toString()
            done()

    it "Integration stamp", (done) ->
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
        e(Object.keys(deps)).to.eql e_deps
        fa.forEach stamping, ((obj, callback) ->
          ctx = new nct.Context(context)
          ctx = ctx.push(obj)
          render ctx, (err, result, filename, deps) ->
            e(Object.keys(deps)).to.eql ['test.js']
            fs.readFile path.join(__dirname, "fixtures/#{filename}"), (err, f) ->
              e(result).to.equal f.toString()
              callback()
              # t.same deps, Object.keys(nct.deps('{slug}.html'))
        ), (err, results) ->
          done()

    it "Integration stamp outside block", (done) ->
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
                e(result).to.equal f.toString()
                callback()
                # t.same deps, Object.keys(nct.deps('{slug}.html'))
          ), (err, results) ->
            done()

    it "Custom context lookups by command", (done) ->
      context =
        view: (cb,ctx,params,calledfrom) ->
          if calledfrom == "stamp"
            cb(null, "query")
          else
            cb(null, [{title: calledfrom, slug: "1"}])

      nct.loadTemplate "{# view}{title}{/#}", "t"
      nct.render "t", context, (err, result) ->
        e(result).to.equal "each"

        nct.loadTemplate "{stamp view}{title}{/stamp}", "{slug}"
        nct.stamp "{slug}", context, (err, render, deps, stamping) ->
          e(stamping).to.equal "query"
          render {title: "One", slug: "1"}, (err, result, name, deps) ->
            e(result).to.equal "One", result
            e(name).to.equal "1"
            done()

    it "Failing template", (done) ->
      context =
        view: (cb, ctx, params) ->
          array = [{title: "title: #{x}"} for x in [0..100]]
          cb(null, array[0])

      nct.render "failing.html", context, (err, rendered, deps) ->
        e(err).to.not.exit
        e(rendered).to.match /title: 10/
        done()

