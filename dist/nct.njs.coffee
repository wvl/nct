module.exports =
  modules: 
    'fa': [require.resolve('fa')]
    'underscore.string': [require.resolve('underscore.string')]
    'nct': ['../lib/nct.js', 'compiler.js']

  alt:
    'underscore': '_'
    'fs': '{}'
    'path': '{dirname: function(name) {return "ignore"; }, exists: function() { return false;}}'
    'util': 'null'
