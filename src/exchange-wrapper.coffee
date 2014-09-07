Q = require 'q'

module.exports = class ExchangeWrapper

    constructor: (@exchange) ->

    publish: (routingKey, message, options) ->
        def = Q.defer()
        @exchange.publish routingKey, message, options, (err) ->
            if err
                def.reject err
            else
                def.resolve()
        def.promise
        
    
