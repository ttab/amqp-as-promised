log        = require 'bog'
AmqpClient = require './amqp-client'
Rpc        = require './rpc'
RpcBackend = require './rpc-backend'

# facade that ties together the various pieces
module.exports = (conf = {}) -> new Promise (resolve, reject) ->
    # set log level if defined in config
    log.level conf.logLevel if conf.logLevel

    # support old-style configuration
    conf = { connection: conf } if not conf.connection

    client = new AmqpClient(conf)
    client.connect().then =>
        rpc        = new Rpc client, conf.rpc
        rpcBackend = new RpcBackend client

        return resolve({
            on: client.on.bind(client)
            exchange: client.exchange
            queue: client.queue
            bind: client.bind
            rpc: rpc.rpc
            serve: rpcBackend.serve
            shutdown: client.shutdown
            local: client.local
        })
    .catch (err) ->
        reject(err)

module.exports.RpcError = require './rpc-error'
