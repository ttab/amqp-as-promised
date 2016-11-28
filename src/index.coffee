log        = require 'bog'
AmqpClient = require './amqp-client'
Rpc        = require './rpc'
RpcBackend = require './rpc-backend'

# facade that ties together the various pieces
module.exports = (conf = {}) ->

    # set log level if defined in config
    log.level conf.logLevel if conf.logLevel

    # support old-style configuration
    conf = { connection: conf } if not conf.connection

    client     = new AmqpClient conf
    rpc        = new Rpc client, conf.rpc
    rpcBackend = new RpcBackend client

    {
        exchange: client.exchange
        queue: client.queue
        bind: client.bind
        rpc: rpc.rpc
        serve: rpcBackend.serve
        shutdown: client.shutdown
        local: client.local
    }

module.exports.RpcError = require './rpc-error'
