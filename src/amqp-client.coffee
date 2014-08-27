log  = require 'bog'
Q    = require 'q'
amqp = require 'amqp'

# Queue wrapper that only exposes that which we want to exposes in a promise manner
class QueueWrapper

    constructor: (@conn, @queue) ->
        @name = @queue.name
        # For anonymous queues, the name of the underlying queue will
        # change if we get reconnected to the server.
        @queue.on 'open', (name) =>
            @name = name

    bind: (ex, topic) =>
        throw new Error('Exchange is not an object') unless ex or typeof ex != 'object'
        throw new Error('Topic is not a string') unless topic or typeof topic != 'string'
        def = Q.defer()
        @unbind().then =>
            log.info 'binding:', ex.name, @name, topic
            @queue.bind ex, topic
            @queue.once 'queueBindOk', =>
                @_ex = ex
                @_topic = topic
                log.info 'queue bound:', @name, @_topic
                def.resolve this
        .done()
        def.promise

    unbind: =>
        def = Q.defer()
        unless @_ex
            def.resolve this
            return def.promise
        @conn.then (mq) =>
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
        @unsubscribe().then =>
            wrapper = =>
                try
                    callb.apply null, arguments
                catch err
                    log.error err
            (@queue.subscribe opts, wrapper).addCallback (ok) =>
                ctag = ok.consumerTag
                @_ctag = ctag
                log.info 'subscribed:', @name, ctag
                def.resolve this
        .done()
        def.promise

    unsubscribe: =>
        def = Q.defer()
        unless @_ctag
            def.resolve this
            return def.promise
        ctag = @_ctag
        delete @_ctag
        @queue.unsubscribe ctag
        log.info 'unsubscribed:', @name, ctag
        def.resolve this
        def.promise

    isDurable: => @queue.options.durable

    isAutoDelete: => @queue.options.autoDelete

    shift: =>
        @queue.shift.apply @queue, arguments


module.exports = (conf) ->
        
    local = conf.local || process.env.LOCAL
    log.info("local means no amqp connection") if local

    isShutdown = null

    conn = do ->
        # disable if local
        return Q(local:true) if local
        log.info "Connecting", conf.connection
        def = Q.defer()
        # amqp connection
        mq = amqp.createConnection conf.connection
        mq._ttQueues = mq._ttQueues ? {}
        mq.on 'ready', (ev) ->
            log.info 'amqp connection ready'
            def.resolve mq
        mq.on 'error', (err) ->
            if def.promise.isPending()
                def.reject err
                # disable reconnects (a bit of a hack)
                mq.backoff = mq.reconnect = -> false
                log.warn 'amqp connection failed:', err
            else if def.promise.isFulfilled()
                unless isShutdown
                    log.warn 'amqp connection failed:',
                        (if err.message then err.message else err)
        def.promise

    exchange = (name, opts) ->
        throw new Error 'Unable connect exchange when local' if local
        throw new Error 'Unable connect exchange when shutdown' if isShutdown
        def = Q.defer()
        conn.then (mq) ->
            mq._ttExchanges = mq._ttExchanges ? {}
            prom = mq._ttExchanges[name]
            return (prom.then (ex) -> def.resolve ex) if prom
            mq._ttExchanges[name] = def.promise
            opts = opts ? {passive:true}
            mq.exchange name, opts, (ex) ->
                log.info 'exchange ready:', ex.name
                def.resolve ex
        .done()
        def.promise

    queue = (qname, opts) ->
        throw new Error 'Unable to connect queue when local' if local
        throw new Error 'Unable to connect queue shutdown' if isShutdown
        if qname != null and typeof qname == 'object'
            opts = qname
            qname = ''
        qname = '' if !qname
        opts = opts ? { durable: true, autoDelete: false, exclusive: qname == '' }
        def = Q.defer()
        conn.then (mq) ->
            if qname != ''
                prom = mq._ttQueues[qname]
                return (prom.then (q) -> def.resolve q) if prom
                mq._ttQueues[qname] = def.promise
            mq.queue qname, opts, (queue) ->
                log.info 'queue created:', queue.name
                mq._ttQueues[queue.name] = def.promise if qname == ''
                def.resolve new QueueWrapper(conn, queue)
        .done()
        def.promise

    bind = (exname, qname, topic, callback) ->
        throw new Error 'Unable to bind when local' if local
        throw new Error 'Unable to bind when shutdown' if isShutdown
        if typeof topic == 'function'
            callback = topic
            topic = qname
            qname = ''
        qname = '' if not qname
        def = Q.defer()
        (Q.all [(exchange exname), (queue qname)]).spread (ex, q) ->
            Q.fcall ->
                q.bind ex, topic
            .then (q) ->
                if callback?
                    q.subscribe callback
            .then ->
                def.resolve q.name
        .done()
        def.promise

    unbind = (qname) ->
        def = Q.defer()
        conn.then (mq) ->
            return def.resolve true if mq.local
            qp = mq._ttQueues[qname]
            return def.resolve mq unless qp
            qp
        .then (q) ->
            q.unbind()
        .then (q) ->
            q.unsubscribe()
        .then ->
            def.resolve qname
        .done()
        def.promise

    shutdownDef = null
    shutdown = ->
        return isShutdown.promise if isShutdown
        def = isShutdown = Q.defer()
        conn.then (mq) ->
            return def.resolve true if mq.local
            todo = for qname, qp of mq._ttQueues
                qp.then (queue) ->
                    unbind qname if queue.isAutoDelete()
            Q.all(todo)
            .then ->
                log.info 'closing amqp connection'
                # compensate for utterly broken reconnect code
                mq.backoff = mq.reconnect = mq.connect = -> false
                mq.end()
                log.info 'amqp closed'
                def.resolve true
        .done()
        def.promise

    {
        exchange: exchange
        queue: queue
        bind: bind
        shutdown: shutdown
        local: local
        _QueueWrapper: QueueWrapper
    }

