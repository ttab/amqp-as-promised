{ EventEmitter } = require 'events'
ExchangeWrapper  = require '../src/exchange-wrapper'

describe 'ExchangeWrapper', ->

    client = channel = exchange = _exchange = undefined
    beforeEach ->
        channel = new EventEmitter
        channel.publish = stub().returns true
        client =
            compat: require '../src/compat-node-amqp'
        _exchange = { exchange: 'panda' }
        exchange = new ExchangeWrapper client, _exchange, channel

    describe '.publish()', ->

        it 'should publish the message', ->
            exchange.publish 'cub', new Buffer('panda')
            .then ->
                channel.publish.should.have.been.calledWith 'panda', 'cub', match.instanceOf(Buffer), match
                    contentType: 'application/octet-stream'

        it 'resolves the promise immediately if the write buffer is not full', ->
            exchange.publish 'cub', new Buffer('panda')

        it 'waits for drain if the write buffer is full', ->
            channel.publish.returns false
            setTimeout (-> channel.emit 'drain'), 100
            exchange.publish 'cub', new Buffer('panda')

        it 'rejects publish if client is shutting down', ->
            client.shuttingDown = true
            exchange.publish('cub', new Buffer('panda')).should.eventually.be.rejected
