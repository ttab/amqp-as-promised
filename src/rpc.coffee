Q     = require 'q'
uuid  = require 'uuid'
Cache = require 'mem-cache'

module.exports = class Rpc
    constructor: (@amqpc, options) ->
        @responses = new Cache
            timeout: options?.timeout || 1000
        @responses.on 'expired', (ev) ->
            ev.value.reject new Error 'timeout'

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
        @responses.set corrId, def
        return def

    resolveResponse: (corrId, msg, headers) =>
        if @responses.get corrId
            @responses.get(corrId).resolve msg
            @responses.remove corrId

    rpc: (exname, routingKey, msg, headers) =>
        throw new Error 'Must provide msg' unless msg
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
