log        = require 'bog'
amqpClient = require './amqp-client'
Rpc        = require './rpc'
RpcBackend = require './rpc-backend'

# facade that ties together the various pieces
module.exports = (conf = {}) ->

    # set log level if defined in config
    log.level conf.logLevel if conf.logLevel

    # support old-style configuration
    conf = { connection: conf, local: conf.local } if not conf.connection

    amqpc      = amqpClient conf
    rpc        = new Rpc amqpc, conf.rpc
    rpcBackend = new RpcBackend amqpc

    {
        exchange: amqpc.exchange
        queue: amqpc.queue
        bind: amqpc.bind
        rpc: rpc.rpc
        serve: rpcBackend.serve
        shutdown: amqpc.shutdown
        local: amqpc.local
    }
