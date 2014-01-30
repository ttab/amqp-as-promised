amqpClient = require './amqp-client'
Rpc = new require './rpc'

# facade that ties together the various pieces
module.exports = (conf) ->
    amqpc = amqpClient conf
    rpc = new Rpc amqpc

    {
        exchange: amqpc.exchange
        queue: amqpc.queue
        bind: amqpc.bind
        rpc: rpc.rpc
        shutdown: amqpc.shutdown
        local: amqpc.local
    }
