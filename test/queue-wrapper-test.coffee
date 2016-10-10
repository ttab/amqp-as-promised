{EventEmitter}  = require 'events'
Q               = require 'q'
ExchangeWrapper = require '../src/exchange-wrapper'
QueueWrapper    = require '../src/queue-wrapper'

amqpc = amqpClient = nodeAmqp = undefined

describe 'QueueWrapper', ->

    beforeEach ->
        nodeAmqp = {}
        amqpClient = proxyquire '../src/amqp-client',
            'node-amqp': nodeAmqp

    describe '.bind()', ->
        exchange = queue = wrapper = undefined
        beforeEach ->
            queue = new EventEmitter
            queue.bind = -> queue.emit 'queueBindOk'
            spy queue, 'bind'
            exchange = new ExchangeWrapper name:'my-exchange'
            amqpc = exchange: -> Q exchange
            wrapper = new QueueWrapper amqpc, queue

        it 'should accept the name of an exchange as arg', ->
            wrapper.bind('my-exchange', 'routing.key').then ->
                queue.bind.should.have.been.calledWith match({name: 'my-exchange'}), 'routing.key'

        it 'should accept an exchange object as arg', ->
            wrapper.bind(exchange, 'routing.key').then ->
                queue.bind.should.have.been.calledWith match({name: 'my-exchange'}), 'routing.key'

        it 'should signal an error if no topic is given', ->
            wrapper.bind('my-exchange').should.be.rejectedWith 'Topic is not a string'

        it 'should signal an error if topic is not a string', ->
            wrapper.bind('my-exchange', {}).should.be.rejectedWith 'Topic is not a string'

    describe '.subscribe()', ->

        it 'should pass options to .subscribe() on to the wrapped queue', (done) ->
            conn = {}
            queue = { on: -> }
            amqpc = amqpClient { local: true }
            queue.subscribe = stub().returns { addCallback: (fn) -> fn( { consumerTag: 'tag' }) }
            wrapper = new QueueWrapper conn, queue
            wrapper.unsubscribe = stub().returns Q {}

            wrapper.subscribe({panda: true}, ->).then ->
                queue.subscribe.should.have.been.calledWith({panda: true}, match.func)
                done()
            .done()

    it 'should take its name from the underlying queue and update it when it changes', ->
        queue = new EventEmitter
        queue.name = 'panda'
        amqpc = amqpClient { local: true }
        wrapper = new QueueWrapper {}, queue
        wrapper.name.should.equal 'panda'
        queue.emit 'open', 'cub'
        wrapper.name.should.equal 'cub'

    it 'should refuse to do ack:true prefetchCount > 1 and shift()', ->
        conn = {}
        queue = { on: -> }
        amqpc = amqpClient { local: true }
        queue.subscribe = stub().returns self =
            addCallback: (fn) -> fn( { consumerTag: 'tag' }) ; self
            addErrback: -> self
        wrapper = new QueueWrapper conn, queue
        wrapper.unsubscribe = stub().returns Q {}
        wrapper.subscribe({ack:true, prefetchCount:2}, ->).then ->
            expect(->wrapper.shift()).to.throw 'ack:true and prefetchCount > 1 does not work with queue.shift(). use (msg, info, del, ack) => ack.acknowledge()'

    it 'should be ok with ack:true prefetchCount == 1 and shift()', ->
        conn = {}
        queue = {
            on:->
            shift:->
        }
        amqpc = amqpClient { local: true }
        queue.subscribe = stub().returns self =
            addCallback: (fn) -> fn( { consumerTag: 'tag' }) ; self
            addErrback: -> self
        wrapper = new QueueWrapper conn, queue
        wrapper.unsubscribe = stub().returns Q {}

        wrapper.subscribe({ack:true, prefetchCount:1}, ->).then ->
            expect(->wrapper.shift()).to.not.throw
