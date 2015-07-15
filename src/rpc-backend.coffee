log   = require 'bog'
Q     = require 'q'
merge = require './merge'
{compress, decompress} = require './compressor'

module.exports = class RpcBackend
    constructor: (@amqpc) ->

    serve: (exname, topic, callback) =>
        Q.all( [
            @amqpc.exchange exname, { type: 'topic', durable: true, autoDelete: false}
            @amqpc.exchange ''
            @amqpc.queue "#{exname}.#{topic}", { durable: true, autoDelete: false }
        ]).spread (ex, defaultex, queue) =>
            queue.bind ex, topic
            queue.subscribe @_mkcallback(defaultex, callback)

    # Creates a callback funtion which respects replyTo/correlationId
    _mkcallback: (exchange, handler) ->
        (msg, headers, info) ->
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

            # we need to keep track of our queued progress messages
            progress = []

            # maybe decompress compressed payload
            [ct, p] = decompress msg, headers
            merge info, ct

            p.then (payload) ->
                Q.when handler payload, headers, info, (prgs) ->
                    return unless info.correlationId
                    popts =
                        correlationId: info.correlationId + "#x-progress:" + progress.length
                    [h, p] = compress prgs, headers
                    popts.headers = h if h
                    prev = progress[progress.length - 1] ? Q() # previous
                    # progress wait for previous and payload
                    # compressions this is because we could end up in
                    # out-of-order x-progress if we first do a very
                    # large (compressed) payload followed by a very
                    # small one.
                    progress.push Q.all([prev, p]).spread (_, payload) ->
                        exchange.publish info.replyTo, payload, popts
            .then (res) ->
                [h, p] = compress res, headers
                opts.headers = h if h
                return p
            .then (res) ->
                # first, wait for queued progress messages to be sent
                Q.all progress
                .then ->
                    # then send the result
                    exchange.publish info.replyTo, res, opts
            .fail (err) ->
                log.error err
                exchange.publish info.replyTo, { error: err.message }, opts
            .fail (err) ->
                # we need to be careful to catch any errors caused by
                # the publish call in the error handling
                log.error err
