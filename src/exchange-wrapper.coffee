# Q = require 'q'

module.exports = class ExchangeWrapper

    constructor: (@client, @exchange) ->
        @name = @exchange.exchange

    _publish: (routingKey, message, options={}) =>
        options = @client.compat.publishOpts(options)
        options.contentType = 'application/octet-stream' unless options.contentType
        if typeof(message) is 'object' and not (message instanceof Buffer)
            message = new Buffer JSON.stringify message
            options.contentType = 'application/json'
        @client.channel.then (c) =>
            c.publish @name, routingKey, message, options

    publish: (routingKey, message, options) =>
        @client.compat.promise(@_publish routingKey, message, options)
