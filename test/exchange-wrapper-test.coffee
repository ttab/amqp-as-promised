ExchangeWrapper = require '../src/exchange-wrapper'

describe 'ExchangeWrapper', ->

    client = channel = exchange = _exchange = undefined
    beforeEach ->
        channel =
            publish: stub().returns Promise.resolve()
        client =
            channel: Promise.resolve(channel)
            compat: require '../src/compat-node-amqp'
        _exchange = { exchange: 'panda' }
        exchange = new ExchangeWrapper client, _exchange

    describe '.publish()', ->

        it 'should publish the message', ->
            exchange.publish 'cub', new Buffer('panda')
            .then ->
                channel.publish.should.have.been.calledWith 'panda', 'cub', match.instanceOf(Buffer), match
                    contentType: 'application/octet-stream'

        it 'should bufferize plain text messages', ->
            exchange.publish 'cub', 'panda'
            .then ->
                channel.publish.should.have.been.calledWith 'panda', 'cub', match.instanceOf(Buffer), match
                    contentType: 'text/plain'

        it 'should serialize objects as json', ->
            exchange.publish 'cub', { panda: true }
            .then ->
                channel.publish.should.have.been.calledWith 'panda', 'cub', match.instanceOf(Buffer), match
                    contentType: 'application/json'
