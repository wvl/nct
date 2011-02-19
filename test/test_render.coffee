nct = require "../lib/nct"

module.exports =
  "render with no tags": (test) ->
    nct.render "something", {}, (err, result) ->
      test.same "something", result
      test.done()
