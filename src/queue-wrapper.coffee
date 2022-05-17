log          = require('loglevel').getLogger('amqp')

module.exports = class QueueWrapper

    constructor: (@client, @queue, @channel) ->
        @name = @queue.queue

    _bind: (exchange, topic) =>
        topic = '' if not topic
        Promise.resolve().then =>
            throw new Error('Topic is not a string') if typeof topic != 'string'
            Promise.all([
                @unbind()
                @client.exchange(exchange)
            ])
        .then ([whatevs, exchange]) =>
            log.info 'binding:', exchange.name, @name, topic
            @channel.bindQueue(@name, exchange.name, topic).then =>
                @_exchange = exchange.name
                @_topic = topic
                log.info 'queue bound:', @name, @_topic
                @
        .catch (err) ->
            log.error "qw _bind error", err
            Promise.reject(err)


    bind: (exchange, topic) =>
        @client.compat.promise(@_bind exchange, topic)

    _unbind: =>
        return Promise.resolve @ unless @_exchange and @_topic

        @channel.unbindQueue @name, @_exchange, @_topic
        .then =>
            log.info 'queue unbound:', @name, @_topic
            delete @_exchange
            delete @_topic
            @
        .catch (err) ->
            log.error "qw _unbind error", err
            Promise.reject(err)

    unbind: =>
        @client.compat.promise(@_unbind())

    _subscribe: (opts, callback) =>
        if typeof opts == 'function'
            callback = opts
            opts = null
        @unsubscribe().then =>
            if @consumerChannel then @consumerChannel else @client.getChannel()
        .then (@consumerChannel) =>
            opts = @client.compat.subscribeOpts(opts)
            # this is questionable and open to race conditions,
            # but there is no other way to do it
            Promise.all([
                @consumerChannel.prefetch opts.prefetch
                @consumerChannel.consume @queue.queue, @client.compat.callback(@consumerChannel, callback), opts
            ]).then ([whatevs, { consumerTag }]) =>
                @_consumerTag = consumerTag
                log.info 'subscribed:', @name, @_consumerTag
                @
        .catch (err) ->
            log.error "qw _subscribe error", err
            Promise.reject(err)


    subscribe: (opts, callback) =>
        @client.compat.promise(@_subscribe opts, callback)

    _unsubscribe: =>
        return @ unless @_consumerTag and @consumerChannel
        @consumerChannel.cancel(@_consumerTag).then =>
            log.info 'unsubscribed:', @name, @_consumerTag
            delete @_consumerTag
            @
        .catch (err) ->
            log.error "qw _unsub error", err

    unsubscribe: => @client.compat.promise(@_unsubscribe())

    isDurable: => @queue.options.durable

    isAutoDelete: => @queue.options.autoDelete
