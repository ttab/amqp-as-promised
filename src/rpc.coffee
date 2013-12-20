ampqc = require './amqp-client'
Q     = require 'q'

module.exports = class Rpc
    constructor: (@amqpc) ->
        @responses = {}
        @returnChannel = @amqpc.queue('', { autoDelete: true, exclusive: true})
        @returnChannel.then (returnChannel) =>
            returnChannel.subscribe (msg, headers, deliveryInfo) =>
                resolveResponse deliveryInfo.correlationId, msg

    registerResponse: (corrId) =>
        def = Q.defer()
        @responses[corrId] = def
        return def

    resolveResponse: (corrId, msg) =>
        if @responses[corrId]? 
            @responses[corrId].resolve msg
            delete @responses[corrId]
    
    rpc: (exname, routingKey, msg, headers) =>
        Q.all([
            @amqpc.exchange(exname),
            @returnChannel
        ]).spread (ex, q) =>
            def = @registerResponse '1234'
            ex.publish routingKey, msg,
                replyTo: q.name
                headers: headers
            def.promise
