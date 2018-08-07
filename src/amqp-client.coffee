log             = require 'bog'
amqp            = require 'amqplib'
ExchangeWrapper = require './exchange-wrapper'
QueueWrapper    = require './queue-wrapper'

wait = (time) -> new Promise (rs) -> setTimeout rs, time

module.exports = class AmqpClient

    constructor: (@conf, @compat = require('./compat-node-amqp')) ->
        @exchanges = {}
        @queues = {}

    connect: =>
        [ uri, opts ] = @compat.connection(@conf)
        log.info "connecting to:", uri

        amqp.connect(uri, opts).then (@conn) =>
            log.info "connected"
            @conn.on 'error', (err) =>
                log.warn 'amqp error:', (if err.message then err.message else err)
                if typeof @conf?.errorHandler is 'function'
                    @conf.errorHandler err
                else
                    throw err
            return Promise.resolve("ok")
        .catch (err) =>
            if @conf.waitForConnection
                time = @conf.waitForConnection
                time = 1000 if typeof time != 'number'
                log.info "waiting for connection to:", uri
                wait(time).then => @connect(uri, opts)
            else
                Promise.reject(err)

    getChannel: =>
        @conn.createChannel().then (c) =>
            # set max listeners to something arbitrarily large in
            # order to avoid misleading 'memory leak' error messages
            c.setMaxListeners @conf.maxListeners or 1000
            Promise.resolve(c)
        .catch (err) ->
            Promise.reject(err)

    _exchange: (name, type, opts) =>
        return name if name instanceof ExchangeWrapper
        return @exchanges[name] if @exchanges[name]
        @getChannel().then (c) =>
            (if not type
                if name is ''
                    Promise.resolve({ exchange: '' })
                else
                    c.checkExchange(name).then -> { exchange: name }
            else
                c.assertExchange(name, type, opts)
            ).then (e) =>
                log.info 'exchange ready:', e.exchange
                @exchanges[name] = new ExchangeWrapper @, e, c
        .catch (err) ->
            log.error "_echange error", err
            Promise.reject(err)

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

        @getChannel().then (c) =>
            (if not opts
                c.checkQueue(qname)
            else
                c.assertQueue(qname, opts)
            ).then (q) =>
                log.info 'queue created:', q.queue
                @queues[qname] = new QueueWrapper @, q, c
        .catch (err) ->
            log.error "_queue error", err
            Promise.reject(err)


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
        .catch (err) ->
            log.error "_bind error", err
            Promise.reject(err)


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

    shutdown: =>
        @shuttingDown = true
        @compat.promise(@conn?.close())
