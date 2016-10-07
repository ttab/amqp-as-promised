log          = require 'bog'
Q            = require 'q'

# Queue wrapper that only exposes that which we want to exposes in a promise manner
module.exports = class QueueWrapper

    constructor: (@amqpc, @queue) ->
        @name = @queue.name
        # For anonymous queues, the name of the underlying queue will
        # change if we get reconnected to the server.
        @queue.on 'open', (name) =>
            @name = name

    bind: (exchange, topic) =>
        Q().then =>
            throw new Error('Topic is not a string') if not topic or typeof topic != 'string'
            @amqpc.exchange(exchange)
        .then (exwrapper) =>
            ex = exwrapper.exchange
            def = Q.defer()
            @unbind().then =>
                log.info 'binding:', ex.name, @name, topic
                @queue.once 'queueBindOk', =>
                    @_ex = ex
                    @_topic = topic
                    log.info 'queue bound:', @name, @_topic
                    def.resolve this
                @queue.bind ex, topic
            .done()
            def.promise

    unbind: =>
        def = Q.defer()
        if !@_ex or !@amqpc.conn
            def.resolve this
            return def.promise
        @amqpc.conn.then (mq) =>
            @queue.unbind @_ex, @_topic
            @queue.once 'queueUnbindOk', =>
                log.info 'queue unbound:', @name, @_topic
                delete @_ex
                delete @_topic
                def.resolve this
        .done()
        def.promise

    subscribe: (opts, callb) =>
        def = Q.defer()
        if typeof opts == 'function'
            callb = opts
            opts = null
        opts = opts ? {ack: false, prefetchCount: 1}
        throw new Error('Opts is not an object') unless opts or typeof opts != 'object'
        throw new Error('Callback is not a function') unless callb or typeof callb != 'function'
        if !!opts.ack and opts.prefetchCount > 1
            @noshifting = true
        @unsubscribe().then =>
            wrapper = ->
                try
                    callb.apply null, arguments
                catch err
                    log.error err
            (@queue.subscribe opts, wrapper).addCallback (ok) =>
                ctag = ok.consumerTag
                @_ctag = ctag
                log.info 'subscribed:', @name, ctag
                def.resolve this
            .addErrback (err) ->
                def.reject err
        .done()
        def.promise

    unsubscribe: =>
        def = Q.defer()
        unless @_ctag
            def.resolve this
            return def.promise
        ctag = @_ctag
        delete @_ctag
        (@queue.unsubscribe ctag).addCallback =>
            log.info 'unsubscribed:', @name, ctag
            def.resolve this
        .addErrback (err) ->
            def.reject err
        def.promise

    isDurable: => @queue.options.durable

    isAutoDelete: => @queue.options.autoDelete

    shift: =>
        if @noshifting
            throw new Error("ack:true and prefetchCount > 1 does not
                work with queue.shift(). use (msg, info, del, ack) => ack.acknowledge()")
        @queue.shift.apply @queue, arguments
