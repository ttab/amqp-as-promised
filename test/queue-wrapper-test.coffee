{EventEmitter}  = require 'events'
ExchangeWrapper = require '../src/exchange-wrapper'
QueueWrapper    = require '../src/queue-wrapper'

describe 'QueueWrapper', ->

    client = channel = queue = _queue = exchange = undefined
    beforeEach ->
        exchange = name: 'my-exchange'
        channel =
            consume: stub().returns Promise.resolve { consumerTag: '1234' }
            prefetch: stub().returns Promise.resolve()
            cancel: stub().returns Promise.resolve()
            bindQueue: stub().returns Promise.resolve()
            unbindQueue: stub().returns Promise.resolve()
        client =
            getChannel: Promise.resolve(channel)
            compat: require '../src/compat-node-amqp'
            exchange: stub().returns Promise.resolve exchange
        _queue = { queue: 'pandas' }
        queue = new QueueWrapper client, _queue, channel
        spy queue, 'bind'

    it 'should take its name from the underlying queue', ->
        queue.name.should.equal 'pandas'

    describe '.subscribe()', ->
        cb = undefined
        beforeEach ->
            cb = spy()

        it 'should unsubscribe before subscribing', ->
            spy queue, 'unsubscribe'
            queue.subscribe {}, cb
            .then ->
                queue.unsubscribe.should.have.been.called

        it 'should return a reference to itself', ->
            queue.subscribe {}, cb
            .should.eventually.equal queue

        it 'should set prefetch before subscribing', ->
            queue.subscribe { prefetchCount: 23 }, cb
            .then ->
                channel.prefetch.should.have.been.calledWith 23
                channel.prefetch.should.have.been.calledBefore channel.consume

        it 'should assume prefetch=1', ->
            queue.subscribe { }, cb
            .then ->
                channel.prefetch.should.have.been.calledWith 1

        it 'should be possible so set prefetch=0', ->
            queue.subscribe { prefetchCount: 0 }, cb
            .then ->
                channel.prefetch.should.have.been.calledWith 0

        it 'should pass on <msg>, <headers>, <info>, <ack> to the callback', ->
            queue.subscribe {}, cb
            .then ->
                channel.consume.should.have.been.calledWith 'pandas', match.func
                channel.consume.firstCall.args[1] {
                    properties:
                        headers: { 'x-panda': true }
                        contentType: 'application/octet-stream'
                    fields:
                        routingKey: 'cub'
                    content: Buffer.from('{"panda": true}')
                }
                cb.should.have.been.calledWith \
                    match { data: match.instanceOf(Buffer), contentType: 'application/octet-stream' },
                    { 'x-panda': true },
                    match { routingKey: 'cub', contentType: 'application/octet-stream' },
                    match acknowledge: match.func

        it 'should deserialize json payloads', ->
            queue.subscribe {}, cb
            .then ->
                channel.consume.should.have.been.calledWith 'pandas', match.func
                channel.consume.firstCall.args[1] {
                    properties:
                        contentType: 'application/json'
                    fields: {}
                    content: Buffer.from('{"panda": true}')
                }
                cb.should.have.been.calledWith { panda: true }, {},
                    match { contentType: 'application/json' }

        it 'should pass options to .subscribe() on to the wrapped queue', ->
            queue.subscribe({exclusive: true}, ->)
            .then ->
                channel.consume.should.have.been.calledWith('pandas', match.func, {noAck: true, exclusive: true, prefetch: 1})

    describe '.unsubscribe()', ->

        it 'should unsubscribe a previously subscribed handler', ->
            queue.subscribe(->)
            .then ->
                channel.consume.should.have.been.calledWith 'pandas', match.func
                queue._consumerTag.should.equal '1234'
                queue.unsubscribe().should.eventually.equal queue
                .then ->
                    channel.cancel.should.have.been.calledWith '1234'
                    expect(queue._consumerTag).to.be.undefined

        it 'should just return if it was already unsubscribed', ->
            queue.unsubscribe().should.eventually.equal queue
            .then ->
                channel.cancel.should.not.have.been.called
                expect(queue._consumerTag).to.be.undefined

    describe '.bind()', ->

        it 'should unbind before binding', ->
            spy queue, 'unbind'
            queue.bind('my-exchange', 'routing.key').then ->
                queue.unbind.should.have.been.called

        it 'should accept the name of an exchange as arg', ->
            queue.bind('my-exchange', 'routing.key').then ->
                channel.bindQueue.should.have.been.calledWith 'pandas', 'my-exchange', 'routing.key'

        it 'should accept an exchange object as arg', ->
            queue.bind(exchange, 'routing.key').then ->
                channel.bindQueue.should.have.been.calledWith 'pandas', 'my-exchange', 'routing.key'

        it 'should signal an error if topic is not a string', ->
            queue.bind('my-exchange', {}).should.be.rejectedWith 'Topic is not a string'

        it 'should return a promise for @', ->
            queue.bind(exchange, 'routing.key').should.eventually.equal queue


    describe '.unbind()', ->

        it 'should unbind a previously bound queue', ->
            queue.bind('my-exchange', '#').then ->
                queue._exchange.should.equal 'my-exchange'
                queue._topic.should.equal '#'
                queue.unbind().should.eventually.equal queue
                .then ->
                    channel.unbindQueue.should.have.been.calledWith 'pandas', 'my-exchange', '#'
                    expect(queue._exchange).to.be.undefined
                    expect(queue._topic).to.be.undefined

        it 'should just return if it was not already bound', ->
            queue.unbind().should.eventually.equal queue
            .then ->
                channel.unbindQueue.should.not.have.been.called
                expect(queue._exchange).to.be.undefined
                expect(queue._topic).to.be.undefined
