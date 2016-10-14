# Q               = require 'q'
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

        it 'should serialize objects as json', ->
            exchange.publish 'cub', { panda: true }
            .then ->
                channel.publish.should.have.been.calledWith 'panda', 'cub', match.instanceOf(Buffer), match
                    contentType: 'application/json'

describe.skip 'ExchangeWrapper', ->
    exchange = wrapper = undefined

    describe 'with options:confirm:true', ->

        beforeEach ->
            exchange = { publish: stub(), options:confirm:true }
            wrapper  = new ExchangeWrapper exchange

        describe '.publish()', ->
            it 'should return a promise', ->
                expect(Q.isPromise(wrapper.publish("routing.key", "msg"))).to.be.true

            it 'should call publish() on the underlying exchange', ->
                exchange.publish.callsArg 3
                wrapper.publish("routing.key", "msg", { my: 'option' }).should.eventually.be.fulfilled
                .then ->
                    exchange.publish.should.have.been.calledWith "routing.key", "msg", { my: 'option' }

            it 'should reject the promise if the underlying exchange signals an error', ->
                exchange.publish.callsArgWith 3, 'error!'
                wrapper.publish("routing.key", "msg", { my: 'option' }).should.eventually.be.rejectedWith 'error!'

    describe 'with no options:confirm:true', ->

        beforeEach ->
            exchange = { publish: stub() }
            wrapper  = new ExchangeWrapper exchange

        describe '.publish()', ->
            it 'should return a promise', ->
                expect(Q.isPromise(wrapper.publish("routing.key", "msg"))).to.be.true

            it 'should call publish() on the underlying exchange', ->
                wrapper.publish("routing.key", "msg", { my: 'option' }).should.eventually.be.fulfilled
                .then ->
                    exchange.publish.should.have.been.calledWith "routing.key", "msg", { my: 'option' }
