FIELDS = [ 'message', 'code', 'errno' ]

class RpcError extends Error

module.exports = (payload) ->
    return Promise.resolve payload unless payload?.error
    err = new RpcError
    err[f] = payload.error[f] for f in FIELDS when payload.error[f]
    err.message = payload.error.toString() if Object.keys(err).length is 0
    return Promise.reject err
