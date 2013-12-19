log = require 'bog'
Q = require 'q'
amqp = require 'amqp'

module.exports = (conf) ->

    log.info("conf.local=true means no amqp connection") if conf.local

    isShutdown = null

    conn = do ->
        # disable if local
        return Q(local:true) if conf.local
        log.info "Connecting", conf
        def = Q.defer()
        # amqp connection
        mq = amqp.createConnection conf
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
                    log.warn 'amqp connection failed:', (if err.message then err.message else err)
        def.promise

    exchange = (name, opts) ->
        throw new Error 'Unable connect exchange when conf.local = true' if conf.local
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
        throw new Error 'Unable to connect queue when conf.local = true' if conf.local
        throw new Error 'Unable to connect queue shutdown' if isShutdown
        def = Q.defer()
        conn.then (mq) ->
            if qname != ""
                prom = mq._ttQueues[qname]
                return (prom.then (q) -> def.resolve q) if prom
                mq._ttQueues[qname] = def.promise if qname
            opts = opts ? { durable: true, autoDelete: qname == "" }
            mq.queue qname, opts, (queue) ->
                log.info 'queue created:', queue.name
                mq._ttQueues[queue.name] = def.promise if qname == ""
                def.resolve wrapQueue queue
        .done()
        def.promise

    wrapQueue = (q) ->
        qname = q.name
        bind: (ex, topic) ->
            def = Q.defer()
            (unbind qname).then ->
                log.info 'binding:', ex.name, qname, topic
                q.bind ex, topic
                q.on 'queueBindOk', ->
                    wrap = ->
                        try
                            callback.apply(null, arguments)
                        catch err
                            log.error err
                    (q.subscribe wrap).addCallback (ok) ->
                        ctag = ok.consumerTag
                        q._ttCtag = ctag
                        q._ttEx = ex
                        q._ttTopic = topic
                        log.info 'consumer bound:', qname, ctag
                        def.resolve qname
            .done()
            def.promise
        unbind: ->
            def = Q.defer()
            return def.resolve qname unless q._ttEx
            log.info 'unbinding:', qname
            conn.then (mq) ->
                q.unbind q._ttEx, q._ttTopic
                q.on 'queueUnbindOk', ->
                    try
                        ctag = q._ttCtag
                        delete q._ttCtag
                        delete q._ttEx
                        delete q._ttTopic
                        q.unsubscribe ctag
                        delete mq._ttQueues[qname]
                        log.info 'consumer unbound:', qname, ctag
                        def.resolve qname
                    catch err
                        log.error 'unbind failed', err
            .done()
            def.promise

    bind = (exname, qname, topic, callback) ->
        throw new Error 'Unable to bind when conf.local = true' if conf.local
        throw new Error 'Unable to bind when shutdown' if isShutdown
        if typeof topic == 'function'
            callback = topic
            topic = qname
            qname = ""
        qname = "" if not qname
        def = Q.defer()
        (Q.all [(exchange exname), (queue qname)]).spread (ex, q) ->
            (q.bind ex, topic).then -> def.resolve ex
        .done()
        def.promise

    unbind = (qname) ->
        def = Q.defer()
        conn.then (mq) ->
            return def.resolve true if mq.local
            qp = mq._ttQueues[qname]
            return def.resolve mq unless qp
            qp.then (q) -> q.unbind()
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
            Q.all(unbind qname for qname, qp of mq._ttQueues)
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
        local: conf.local
    }
