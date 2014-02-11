amqpClient = require './amqp-client'
Rpc        = require './rpc'
RpcBackend = require './rpc-backend'

# facade that ties together the various pieces
module.exports = (conf) ->
    amqpc      = amqpClient conf
    rpc        = new Rpc amqpc
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
