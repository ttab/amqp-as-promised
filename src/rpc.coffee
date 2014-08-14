Q     = require 'q'
uuid  = require 'uuid'
Cache = require 'mem-cache'

module.exports = class Rpc
    constructor: (@amqpc, options) ->
        @responses = new Cache
            timeout: options?.timeout || 1000
        @responses.on 'expired', (ev) ->
            if typeof ev?.value?.def.reject == 'function'
                ev.value.def.reject new Error "timeout: #{ev.value.options?.info}"

    returnChannel: =>
        if !@_returnChannel
            @_returnChannel = @amqpc.queue('', { autoDelete: true, exclusive: true})
            @_returnChannel.then (q) =>
                q.subscribe (msg, headers, deliveryInfo) =>
                    if deliveryInfo?
                        @resolveResponse deliveryInfo.correlationId, msg
        return @_returnChannel

    registerResponse: (corrId, options) =>
        def = Q.defer()
        options = options || {}
        value = {def:def, options:options}
        @responses.set corrId, value, options.timeout
        return def

    resolveResponse: (corrId, msg, headers) =>
        if @responses.get corrId
            @responses.get(corrId).def.resolve msg
            @responses.remove corrId

    rpc: (exname, routingKey, msg, headers, options) =>
        throw new Error 'Must provide msg' unless msg
        Q.all([
            @amqpc.exchange(exname),
            @returnChannel()
        ]).spread (ex, q) =>
            id = uuid.v4()
            options         = options || {}
            options.info    = options.info || "#{exname}/#{routingKey}"
            def = @registerResponse id, options
            opts = { replyTo: q.name, correlationId: id }
            opts.headers = headers if headers?
            ex.publish routingKey, msg, opts
            def.promise
