log          = require 'bog'

module.exports = class QueueWrapper

    constructor: (@client, @queue) ->
        @name = @queue.queue

    _bind: (exchange, topic) =>
        topic = '' if not topic
        Promise.resolve().then ->
            throw new Error('Topic is not a string') if typeof topic != 'string'
        .then =>
            @unbind()
        .then =>
            @client.exchange(exchange)
        .then (exchange) =>
            log.info 'binding:', exchange.name, @name, topic
            @client.channel.then (c) =>
                c.bindQueue @name, exchange.name, topic
            .then =>
                @_exchange = exchange.name
                @_topic = topic
                log.info 'queue bound:', @name, @_topic
                @

    bind: (exchange, topic) =>
        @client.compat.promise(@_bind exchange, topic)

    _unbind: =>
        return Promise.resolve @ unless @_exchange and @_topic
        @client.channel.then (c) =>
            c.unbindQueue @name, @_exchange, @_topic
            .then =>
                log.info 'queue unbound:', @name, @_topic
                delete @_exchange
                delete @_topic
                @

    unbind: => @client.compat.promise(@_unbind())

    _subscribe: (opts, callback) =>
        if typeof opts == 'function'
            callback = opts
            opts = null
        @unsubscribe().then =>
            @client.channel.then (c) =>
                opts = @client.compat.subscribeOpts(opts)
                # this is questionable and open to race conditions,
                # but there is no other way to do it
                Promise.all([
                    c.prefetch opts.prefetch
                    c.consume @queue.queue, @client.compat.callback(@client, callback), opts
                ]).then ([whatevs, { consumerTag }]) =>
                    @_consumerTag = consumerTag
                    @

    subscribe: (opts, callback) =>
        @client.compat.promise(@_subscribe opts, callback)

    _unsubscribe: =>
        return Promise.resolve @ unless @_consumerTag
        @client.channel.then (c) =>
            c.cancel @_consumerTag
        .then =>
            log.info 'unsubscribed:', @name, @_consumerTag
            delete @_consumerTag
            @

    unsubscribe: => @client.compat.promise(@_unsubscribe())

    isDurable: => @queue.options.durable

    isAutoDelete: => @queue.options.autoDelete
