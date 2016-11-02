log = require 'bog'

promise = undefined
try
    promise = require 'q'
    log.info 'Q promises available'
catch err
    promise = (v) -> Promise.resolve v

module.exports =

    promise: promise

    connection: (conf) ->
        conn = conf.connection
        if conn.url
            [ conn.url ]
        else
            [ "amqp://#{conn.login}:#{conn.password}@#{conn.host}/#{conn.vhost}"]

    exchangeArgs: (name, opts) ->
        if Object.keys(opts ? {}).length isnt 0 and not opts?.passive
            type = opts.type or 'topic'
            o = {}
            o[k] = v for k, v of opts when k in [ 'durable', 'autoDelete'] and v
            o.durable = false unless o.durable?
            [ name, type, o ]
        else
            [ name ]

    queueArgs: (qname, opts) -> [ qname, opts ]

    publishOpts: (opts) -> opts

    subscribeOpts: (opts) ->
        noAck     : !opts?.ack
        exclusive : opts?.exclusive
        prefetch  : if opts?.prefetchCount? then opts.prefetchCount else 1

    callback: (client, cb) ->
        (data) ->
            headers = data.properties?.headers or {}
            info =
                consumerTag     : data.fields?.consumerTag
                deliveryTag     : data.fields?.deliveryTag
                redelivered     : data.fields?.redelivered
                exchange        : data.fields?.exchange
                routingKey      : data.fields?.routingKey
                contentType     : data.properties?.contentType
                contentEncoding : data.properties?.contentEncoding
                headers         : data.properties?.headers
                deliveryMode    : data.properties?.deliveryMode
                priority        : data.properties?.priority
                correlationId   : data.properties?.correlationId
                replyTo         : data.properties?.replyTo
                expiration      : data.properties?.expiration
                messageId       : data.properties?.messageId
                timestamp       : data.properties?.timestamp
                type            : data.properties?.type
                userId          : data.properties?.userId
                appId           : data.properties?.appId
                clusterId       : data.properties?.clusterId
            content = if info.contentType is 'application/json'
                JSON.parse data.content
            else if info.contentType is 'text/plain'
                data.content.toString()
            else
                data.content

            ack = acknowledge: ->
                client.channel.then (c)-> c.ack data

            cb content, headers, info, ack
