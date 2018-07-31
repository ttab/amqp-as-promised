log   = require 'bog'
merge = require './merge'
{compress, decompress} = require './compressor'

# only ack if we actually are in ack mode, otherwise business as usual
# to be backwards compatible.
doack = (opts, ack) -> (cb) ->
    if opts?.ack
        Promise.resolve().then ->
            cb()
        .then ->
            ack.acknowledge(false)       # accept
        .catch ->
            ack.acknowledge(true, false) # reject, no requeue
            # deliberately not rethrow
    else
        cb()

module.exports = class RpcBackend
    constructor: (@client) ->

    serve: (exname, topic, opts, callback) =>
        # backwards compatible with 3 args
        if typeof opts == 'function'
            callback = opts
            opts = null
        opts = opts ? {}

        Promise.all( [
            @client.exchange exname, { type: 'topic', durable: true, autoDelete: false}
            @client.exchange ''
            @client.queue "#{exname}.#{topic}", { durable: true, autoDelete: false }
        ]).then ([ex, defaultex, queue]) =>
            queue.bind ex, topic
            queue.subscribe opts, @_mkcallback(defaultex, callback, opts)

    # Creates a callback funtion which respects replyTo/correlationId
    _mkcallback: (exchange, handler, subopts, serializeError=require('./error-serializer')) ->
        (msg, headers, info, ack) -> doack(subopts, ack) ->
            # no replyTo, no rpc
            return unless info.replyTo?
            # in amqp info is bogus since it got seconds as resolution
            # we use timestamp in headers and expect milliseconds and
            # fall back on amqp default field.
            timestamp = headers?.timestamp ? (info?.timestamp * 1000)
            timeout = headers?.timeout
            # if we have both a timestamp and timeout we can discard
            # the message if it has expired timestamp
            if timestamp and timeout
                timestamp = new Date(timestamp).getTime() if typeof timestamp == 'string'
                # discard if timeout is passed
                if Date.now() > timestamp + timeout
                    log.info "Discarding timed out message
                    (#{info.replyTo}, #{info.correlationId})"
                    return

            # these options are used when publishing the result and/or
            # error messages
            opts = {}
            opts.correlationId = info.correlationId if info.correlationId?

            # maybe decompress compressed payload
            [ct, p] = decompress msg, headers
            merge info, ct

            p.then (payload) ->
                Promise.resolve handler payload, headers, info
            .then (res) ->
                [h, p] = compress res, headers
                opts.headers = h if h
                return p
            .then (res) ->
                # then send the result
                exchange.publish info.replyTo, res, opts
            .catch (err) ->
                log.error err
                Promise.resolve().then ->
                    exchange.publish(info.replyTo, serializeError(err), opts)
                .then ->
                    throw err if subopts?.ack # let ack see error
                .catch (perr) ->
                    throw perr if subopts?.ack # let ack see publish error
