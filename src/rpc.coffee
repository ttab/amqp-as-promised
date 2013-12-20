Q     = require 'q'
uuid  = require 'uuid'

module.exports = class Rpc
    constructor: (@amqpc) ->
        @responses = {}
        @returnChannel = @amqpc.queue('', { autoDelete: true, exclusive: true})
        @returnChannel.then (returnChannel) =>
            returnChannel.subscribe (msg, headers, deliveryInfo) =>
                if deliveryInfo?
                    @resolveResponse deliveryInfo.correlationId, msg

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
            @returnChannel
        ]).spread (ex, q) =>
            id = uuid.v4()
            def = @registerResponse id
            ex.publish routingKey, msg,
                replyTo: q.name
                correlationId: id
                headers: headers
            def.promise
