log             = require 'bog'
amqp            = require 'amqplib'
ExchangeWrapper = require './exchange-wrapper'
QueueWrapper    = require './queue-wrapper'

module.exports = class AmqpClient

    constructor: (@conf, @compat=require('./compat-node-amqp')) ->
        [ uri, opts ] = @compat.connection(@conf)
        log.info "connecting to:", uri
        @channel = amqp.connect(uri, opts).then (conn) =>
            conn.on 'error', (err) =>
                log.warn 'amqp error:', (if err.message then err.message else err)
                if typeof @conf?.errorHandler is 'function'
                    @conf.errorHandler err
                else
                    throw err
            conn.createChannel()
        @exchanges = {}
        @queues = {}

    _exchange: (name, type, opts) =>
        return Promise.resolve(name) if name instanceof ExchangeWrapper
        return @exchanges[name] if @exchanges[name]
        @exchanges[name] = @channel.then (c) =>
            (if not type
                if name is ''
                    Promise.resolve({ exchange: '' })
                else
                    c.checkExchange(name).then -> { exchange: name }
            else
                c.assertExchange(name, type, opts)
            ).then (e) =>
                log.info 'exchange ready:', e.exchange
                new ExchangeWrapper @, e

    exchange: =>
        [ name, type, opts ] = @compat.exchangeArgs arguments...
        @compat.promise(@_exchange name, type, opts)

    _queue: (qname, opts) =>
        return Promise.resolve(qname) if qname instanceof QueueWrapper
        if qname != null and typeof qname == 'object'
            opts = qname
            qname = ''
        qname = '' if !qname
        opts = opts ? if qname == '' then { exclusive: true }
        return @queues[qname] if @queues[qname] and qname isnt ''
        @queues[qname] = @channel.then (c) =>
            (if not opts
                c.checkQueue(qname)
            else
                c.assertQueue(qname, opts)
            ).then (q) =>
                log.info 'queue created:', q.queue
                new QueueWrapper @, q

    queue: =>
        [ qname, opts ] = @compat.queueArgs.apply(undefined, arguments)
        @compat.promise(@_queue qname, opts)

    _bind: (exchange, queue, topic, callback) =>
        if typeof topic == 'function'
            callback = topic
            topic = queue
            queue = ''
        (Promise.all [(@_exchange exchange), (@_queue queue)])
        .then ([ex, q]) ->
            q.bind ex, topic
            .then (q) ->
                q.subscribe callback if callback?
            .then ->
                return q.name

    bind: (exchange, queue, topic, callback) =>
        @compat.promise(@_bind exchange, queue, topic, callback)

    _unbind: (queue) =>
        @queue(queue).then (q) ->
            q.unbind()
        .then (q) ->
            q.unsubscribe()
        .then ->
            return queue

    unbind: (queue) => @compat.promise(@_unbind queue)

    _shutdown: =>
        @channel.then (c) ->
            c.close()

    shutdown: => @compat.promise(@_shutdown())
