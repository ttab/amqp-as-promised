Q     = require 'q'
uuid  = require 'uuid'
Cache = require 'mem-cache'
merge = require './merge'
{compress, decompress} = require './compressor'

DEFAULT_TIMEOUT = 1000

module.exports = class Rpc

    constructor: (@amqpc, @options) ->
        @timeout = @options?.timeout || DEFAULT_TIMEOUT
        @responses = new Cache timeout:@timeout
        @responses.on 'expired', (ev) ->
            if typeof ev?.value?.def.reject == 'function'
                ev.value.def.reject new Error "timeout: #{ev.value.options?.info}"

    returnChannel: =>
        if !@_returnChannel
            @_returnChannel = @amqpc.queue('', { autoDelete: true, exclusive: true})
            @_returnChannel.then (q) =>
                q.subscribe (msg, headers, deliveryInfo) =>
                    @resolveResponse deliveryInfo?.correlationId, msg, headers
        return @_returnChannel

    registerResponse: (corrId, options) =>
        def = Q.defer()
        options = options || {}
        value = {def:def, options:options}
        @responses.set corrId, value, options.timeout
        return def

    resolveResponse: (corrId, msg, headers) =>
        [ corrId, prgsSeq ] = (corrId ? '').split '#x-progress:'
        if response = @responses.get corrId
            [ct, p] = decompress msg, headers
            p.then (payload) =>
                if prgsSeq
                    response.def.notify payload
                else
                    @responses.remove corrId
                    response.def.resolve payload
            .fail (err) ->
                response.def.reject err

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
            # timeout
            timeout = options.timeout || @timeout

            # register the correlation id for response
            def = @registerResponse corrId, options
            # options provided to server
            opts =
                deliveryMode  :  1
                replyTo       : q.name
                correlationId : corrId
                expiration    : "#{timeout}"

            # construct headers
            opts.headers = headers || {}

            # the timeout is provided to server side so server can
            # discard queued up timed out requests.
            opts.headers.timeout = timeout

            # maybe compress the payload
            [h, p] = compress msg, options
            merge opts.headers, h

            # wait for (maybe) compressed payload and then publish
            p.then (payload) ->
                ex.publish routingKey, payload, opts
            .then ->
                # promise for rpc return
                def.promise
