module.exports = class ExchangeWrapper

    constructor: (@client, @exchange) ->
        @name = @exchange.exchange

    _publish: (routingKey, message, options) =>
        @client.channel.then (c) =>
            c.publish @name, routingKey, message, options

    publish: (routingKey, message, options={}) =>
        [ routingKey, message, options ] = @client.compat.publishArgs(routingKey, message, options)
        @client.compat.promise(@_publish routingKey, message, options)
