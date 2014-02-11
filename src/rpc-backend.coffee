log = require 'bog'
Q   = require 'q'

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
            return if ! info.replyTo?
            opts = {}
            opts.correlationId = info.correlationId if info.correlationId?

            handler(msg, headers).then (res) ->
                exchange.publish info.replyTo, res, opts
            .fail (err) ->
                log.error err
                exchange.publish info.replyTo, { error: err.message }, opts
            .done()
