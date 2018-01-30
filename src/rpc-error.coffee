module.exports = class RpcError extends Error
    constructor: (message) ->
        super()
        @message = message if message
