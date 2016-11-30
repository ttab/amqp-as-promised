module.exports = class RpcError extends Error
    constructor: (message) ->
        @message = message if message
        super
