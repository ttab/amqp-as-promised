Q     = require 'q'
uuid  = require 'uuid'

module.exports = class Rpc
    constructor: (@amqpc) ->
        @responses = {}

    returnChannel: =>
        if !@_returnChannel
            @_returnChannel = @amqpc.queue('', { autoDelete: true, exclusive: true})
            @_returnChannel.then (q) =>
                q.subscribe (msg, headers, deliveryInfo) =>
                    if deliveryInfo?
                        @resolveResponse deliveryInfo.correlationId, msg
        return @_returnChannel

    registerResponse: (corrId) =>
        def = Q.defer()
        @responses[corrId] = def
        return def

    resolveResponse: (corrId, msg, headers) =>
        if @responses[corrId]?
            @responses[corrId].resolve [ msg, headers ]
            delete @responses[corrId]

    rpc: (exname, routingKey, msg, headers) =>
        Q.all([
            @amqpc.exchange(exname),
            @returnChannel()
        ]).spread (ex, q) =>
            id = uuid.v4()
            def = @registerResponse id
            opts = { replyTo: q.name, correlationId: id }
            opts.headers = headers if headers?
            ex.publish routingKey, msg, opts
            def.promise
