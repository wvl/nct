var init, _ref;

init = function(nct, _) {
  var applyFilters, _ref;
  if ((_ref = nct.cache) == null) {
    nct.cache = false;
  }
  nct.escape = function(str) {
    if (!str) {
      return "";
    }
    return str.toString().replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, "&apos;");
  };
  nct.doRender = function(tmpl, context) {
    var ctx;
    ctx = context instanceof nct.Context ? context : new nct.Context(context);
    return tmpl(ctx);
  };
  nct.render = function(name, context) {
    return nct.doRender(nct.load(name), context);
  };
  nct.templates = {};
  nct.load = function(name) {
    var src;
    if (nct.templates[name]) {
      return nct.templates[name];
    }
    if (nct.onLoad) {
      src = nct.onLoad(name);
    }
    if (src) {
      return nct.loadTemplate(src, name);
    }
    throw new Error("Template not found: " + name);
  };
  nct.filters = {};
  nct.register = function(tmpl, name) {
    return nct.templates[name] = tmpl;
  };
  nct.r = {};
  nct.r.write = function(data) {
    return function(context) {
      return data;
    };
  };
  applyFilters = function(result, filters) {
    filters.forEach(function(filter) {
      if (!nct.filters[filter]) {
        return result;
      }
      return result = nct.filters[filter](result);
    });
    return result;
  };
  nct.r.mgetout = function(names, params, filters) {
    return function(context, callback) {
      var result;
      result = nct.escape(context.mget(names, params));
      if (filters.length) {
        return applyFilters(result, filters);
      } else {
        return result;
      }
    };
  };
  nct.r.getout = function(name, params, filters) {
    return function(context) {
      var result;
      result = nct.escape(context.get(name, params));
      if (filters.length) {
        return applyFilters(result, filters);
      } else {
        return result;
      }
    };
  };
  nct.r.mgetout_no = function(names, params, filters) {
    return function(context, callback) {
      return context.mget(names, params);
    };
  };
  nct.r.getout_no = function(name, params, filters) {
    return function(context, callback) {
      return context.get(name, params);
    };
  };
  nct.r.mget = function(names, params, calledfrom) {
    return function(context, callback) {
      return context.mget(names, params, callback, calledfrom);
    };
  };
  nct.r.get = function(name, params, calledfrom) {
    return function(context, callback) {
      return context.get(name, params, callback, calledfrom);
    };
  };
  nct.r.doif = function(query, body, elsebody) {
    if (elsebody == null) {
      elsebody = null;
    }
    return function(context, callback) {
      var result, truthy;
      result = query(context);
      truthy = _.isArray(result) ? result.length : result;
      if (truthy) {
        return body(context);
      }
      if (elsebody) {
        return elsebody(context);
      }
      return "";
    };
  };
  nct.r.unless = function(query, body) {
    return function(context, callback) {
      var result;
      result = query(context);
      if (!result) {
        return body(context);
      }
      return "";
    };
  };
  nct.r.multi = function(commands, withstamp) {
    return function(context) {
      var results;
      results = [];
      commands.forEach(function(command, i) {
        return results.push(command(context));
      });
      return results.join('');
    };
  };
  nct.r.each = function(query, command, elsebody) {
    if (elsebody == null) {
      elsebody = null;
    }
    return function(context, callback) {
      var length, loopvar, result;
      loopvar = query(context);
      if (loopvar && (!_.isArray(loopvar) || !_.isEmpty(loopvar))) {
        if (_.isArray(loopvar)) {
          length = loopvar.length;
          result = _.map(loopvar, function(item, i) {
            return command(context.push({
              last: i === length - 1,
              first: i === 0
            }).push(item));
          });
          return result.join('');
        } else {
          return command(context.push(loopvar));
        }
      } else {
        if (elsebody) {
          return elsebody(context);
        } else {
          return "";
        }
      }
    };
  };
  nct.r.partial = function(name) {
    return function(context, callback) {
      var partial;
      partial = nct.load((_.isFunction(name) ? name(context) : name), context);
      if (!partial) {
        return "";
      }
      return partial(context);
    };
  };
  nct.r.block = function(name, command) {
    return function(context, callback) {
      var _base, _ref1;
      return (_ref1 = (_base = context.blocks)[name]) != null ? _ref1 : _base[name] = command(context);
    };
  };
  nct.r.extend = function(name, command) {
    return function(context, callback) {
      var base;
      base = nct.load(name, context);
      if (!base) {
        return "";
      }
      command(context);
      return base(context);
    };
  };
  return nct.Context = (function() {

    function Context(ctx, tail) {
      var _ref1, _ref2;
      this.tail = tail;
      this.head = ctx;
      this.blocks = ((_ref1 = this.tail) != null ? _ref1.blocks : void 0) || {};
      this.deps = ((_ref2 = this.tail) != null ? _ref2.deps : void 0) || {};
    }

    Context.prototype.get = function(key, params, calledfrom) {
      var ctx, value;
      ctx = this;
      while (ctx && ctx.head) {
        if (!_.isArray(ctx.head) && typeof ctx.head === "object") {
          value = ctx.head[key];
          if (value !== void 0) {
            if (typeof value === "function") {
              if (value.length === 0) {
                return value.call(ctx.head);
              } else {
                return value.call(ctx.head, this, params, calledfrom);
              }
            }
            return value;
          }
        }
        ctx = ctx.tail;
      }
      return "";
    };

    Context.prototype.mget = function(keys, params) {
      var k, result, value, _i, _len, _ref1;
      result = this.get(keys[0]);
      if (result === void 0 || result === null) {
        return result;
      }
      _ref1 = keys.slice(1);
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        k = _ref1[_i];
        try {
          value = result[k];
        } catch (e) {
          return "";
        }
        if (typeof value === "function") {
          result = value.call(result, this, params);
        } else {
          result = value;
        }
      }
      return result;
    };

    Context.prototype.push = function(newctx) {
      return new nct.Context(newctx, this);
    };

    return Context;

  })();
};

if (typeof window === 'undefined') {
  module.exports = init;
} else {
  if ((_ref = window.nct) == null) {
    window.nct = {};
  }
  init(window.nct, _);
}
