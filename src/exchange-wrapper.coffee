module.exports = class ExchangeWrapper

    constructor: (@client, @exchange, @channel) ->
        @name = @exchange.exchange

    _publish: (routingKey, message, options) =>
        new Promise (rs, rj) =>
            if @channel.publish @name, routingKey, message, options
                return rs {}
            else
                @channel.once 'drain', -> rs {}

    publish: (routingKey, message, options={}) =>
        return Promise.reject("amqp connection is closing") if @client.shuttingDown
        [ routingKey, message, options ] = @client.compat.publishArgs(routingKey, message, options)
        @client.compat.promise(@_publish routingKey, message, options)
