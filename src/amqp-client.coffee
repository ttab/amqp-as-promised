log             = require 'bog'
Q               = require 'q'
amqp            = require 'amqp'
ExchangeWrapper = require './exchange-wrapper'
QueueWrapper    = require './queue-wrapper'

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
            opts.confirm = true
            mq.exchange name, opts, (ex) ->
                log.info 'exchange ready:', ex.name
                def.resolve new ExchangeWrapper ex
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

