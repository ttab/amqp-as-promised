module.exports =

    connection: (conf) ->
        [ conf ]

    exchangeArgs: (name, type, opts) -> [ name, type, opts ]

    queueArgs: (name, opts) -> [ name, opts ]

    callback: (cb) -> cb
