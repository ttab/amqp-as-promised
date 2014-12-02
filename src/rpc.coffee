Q     = require 'q'
uuid  = require 'uuid'
Cache = require 'mem-cache'

DEFAULT_TIMEOUT = 1000

module.exports = class Rpc

    constructor: (@amqpc, options) ->
        @cacheTimeout = options?.timeout || DEFAULT_TIMEOUT
        @responses = new Cache timeout:@cacheTimeout
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

    rpc: (exchange, routingKey, msg, headers, options) =>
        throw new Error 'Must provide msg' unless msg
        Q.all([
            @amqpc.exchange(exchange)
            @returnChannel()
        ]).spread (ex, q) =>
            # the correlation id used to match up request/response
            corrId = uuid.v4()
            # options stored locally
            options         = options || {}
            options.info    = options.info || "#{ex.name}/#{routingKey}"
            # timestamp for message
            timestamp = options.timestamp || new Date()
            # register the correlation id for response
            def = @registerResponse corrId, options
            # options provided to server
            opts =
                deliveryMode:  1
                replyTo:       q.name
                correlationId: corrId
                # defaults amqp timestamp is bogus. seconds resolution
                timestamp:     timestamp.getTime() / 1000

            opts.headers = headers || {}
            # the timeout is provided to server side so server can
            # discard queued up timed out requests.
            opts.headers.timeout = options.timeout || @cacheTimeout
            opts.headers.timestamp = timestamp.toISOString() # millisecond resolution
            ex.publish routingKey, msg, opts
            def.promise
