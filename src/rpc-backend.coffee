log = require 'bog'
Q   = require 'q'

pick = (o, ks...) -> r = {}; r[k] = o[k] for k in ks when o.hasOwnProperty(k); r

module.exports = class RpcBackend
    constructor: (@amqpc) ->

    serve: (exname, topic, opts, callback) =>
        if typeof opts == 'function'
            callback = opts
            opts = {}
        Q.all( [
            @amqpc.exchange exname, { type: 'topic', durable: true, autoDelete: false}
            @amqpc.exchange ''
            @amqpc.queue "#{exname}.#{topic}", { durable: true, autoDelete: false }
        ]).spread (ex, defaultex, queue) =>
            queue.bind ex, topic
            subopts = pick (opts ? {}), 'ack', 'prefetchCount'
            queue.subscribe subopts, @_mkcallback(defaultex, callback, subopts)

    # Creates a callback funtion which respects replyTo/correlationId
    _mkcallback: (exchange, handler, opts) ->
        doAck = !!opts?.ack
        (msg, headers, info, ack) ->
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
            opts = {}
            opts.correlationId = info.correlationId if info.correlationId?

            handler(msg, headers).then (res) ->
                exchange.publish info.replyTo, res, opts
            .fail (err) ->
                log.error err
                exchange.publish info.replyTo, { error: err.message }, opts
            .finally ->
                ack?.acknowledge() if doAck
            .done()
