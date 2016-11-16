FIELDS = [ 'message', 'code', 'errno' ]

module.exports = (err) ->
    e = {}
    e[f] = err[f] for f in FIELDS when err[f]
    e.message = err.toString() if Object.keys(e).length is 0
    error: e
