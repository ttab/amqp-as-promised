ampqc = require './amqp-client'
Q     = require 'q'

module.exports = class Rpc
    constructor: (@amqpc) ->
        @responses = {}
        @amqpc.queue('', { autoDelete: true, exclusive: true}).then (returnChannel) =>
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
        @amqpc.exchange(exname).then (ex) =>
            def = @registerResponse '1234'
            ex.publish routingKey, msg,
                headers: headers
            def.promise
