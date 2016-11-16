{ EventEmitter } = require 'events'
proxyquire       = require 'proxyquire'
QueueWrapper     = require '../src/queue-wrapper'
ExchangeWrapper  = require '../src/exchange-wrapper'

describe 'AmqpClient', ->

    AmqpClient = amqp = conn = channel = exchange = queue = undefined
    beforeEach ->
        exchange =
            exchange: 'panda'
        queue =
            queue: 'pandas'

        channel = new EventEmitter
        channel.checkExchange =  stub().returns Promise.resolve exchange
        channel.assertExchange =  stub().returns Promise.resolve exchange
        channel.checkQueue =  stub().returns Promise.resolve queue
        channel.assertQueue =  stub().returns Promise.resolve queue
        channel.bindQueue =  stub().returns Promise.resolve()
        channel.unbindQueue =  stub().returns Promise.resolve()
        channel.consume =  stub().returns Promise.resolve { consumerTag: '1234' }
        channel.prefetch = stub().returns Promise.resolve()

        conn = new EventEmitter
        conn.createChannel = stub().returns Promise.resolve channel

        amqp =
            connect: stub().returns Promise.resolve conn
        AmqpClient = proxyquire '../src/amqp-client',
            'amqplib': amqp

    describe '.constructor()', ->

        it 'should connect using conf.uri', ->
            client = new AmqpClient { connection: url: 'amqp://panda' }
            amqp.connect.should.have.been.calledWith 'amqp://panda'

    describe '.exchange()', ->
        client = undefined
        beforeEach ->
            client = new AmqpClient { connection: url: 'amqp://panda' }

        it 'should create an exchange using the specified type', ->
            client.exchange 'panda', { type: 'direct' }
            .then ->
                channel.assertExchange.should.have.been.calledWith 'panda', 'direct'

        it 'should check that the exchange exists if no opts are given', ->
            client.exchange 'panda'
            .then (e) ->
                channel.checkExchange.should.have.been.calledWith 'panda'
                e.name.should.equal 'panda'

        it 'should return a wrapper for the default exchange without calling channel#checkExchange', ->
            client.exchange ''
            .then (e) ->
                channel.checkExchange.should.not.have.been.called
                e.name.should.equal ''

        it 'should check that the exchange exists if no type is given', ->
            client.exchange 'panda', { }
            .then ->
                channel.checkExchange.should.have.been.calledWith 'panda'

        it 'should return an ExchangeWrapper', ->
            client.exchange('panda').should.eventually.be.an.instanceof ExchangeWrapper

        it 'should return the same object if passed an ExchangeWrapper as only argument', ->
            client.exchange('panda').then (ex1) ->
                client.exchange(ex1).then (ex2) ->
                    expect(ex1).to.equal ex2

        it 'should catch errors signalled by amqp, and reject the exchange promise', ->
            channel.checkExchange.returns Promise.reject new Error 'Error!'
            client.exchange('panda').should.eventually.be.rejectedWith 'Error!'

    describe '.queue()', ->
        client = undefined
        beforeEach ->
            client = new AmqpClient { connection: url: 'amqp://panda' }

        it 'should create a queue using the opts given', ->
            client.queue 'pandas', { durable: true }
            .then ->
                channel.assertQueue.should.have.been.calledWith 'pandas', durable: true

        it 'should create an exclusive queue if the name is empty', ->
            client.queue ''
            .then ->
                channel.assertQueue.should.have.been.calledWith '', exclusive: true

        it 'should create an exclusive queue if no arguments were given', ->
            client.queue()
            .then ->
                channel.assertQueue.should.have.been.calledWith '', exclusive: true

        it 'should check that a queue exists if no opts are given', ->
            client.queue 'pandas'
            .then ->
                channel.checkQueue.should.have.been.calledWith 'pandas'

        it 'should pass given name and opts on when creating the queue', ->
            client.queue('pandas', { my: 'option' })
            .then ->
                channel.assertQueue.should.have.been.calledWith 'pandas', { my: 'option' }

        it 'should returns a promise for a QueueWrapper', ->
            client.queue().should.eventually.be.an.instanceof QueueWrapper

        it 'should pass a reference to itself to QueueWrapper', ->
            client.queue().then (q) ->
                q.client.should.equal client

        it 'should return the same object if passed a QueueWrapper as only argument', ->
            client.queue('panda').then (q1) ->
                client.queue(q1).then (q2) ->
                    expect(q1).to.equal q2

        it 'should catch errors signalled by amqp, and reject the queue promise', ->
            channel.checkQueue.returns Promise.reject new Error 'Error!'
            client.queue('panda').should.be.rejectedWith 'Error!'

    describe '.bind()', ->
        client = undefined
        beforeEach ->
            client = new AmqpClient { connection: url: 'amqp://panda' }
            spy client, '_exchange'
            spy client, '_queue'

        it 'should create the exchange', ->
            client.bind 'panda', 'pandas', 'cub.*'
            .then ->
                client._exchange.should.have.been.calledWith 'panda'

        it 'should create the queue', ->
            client.bind 'panda', 'pandas', 'cub.*'
            .then ->
                client._queue.should.have.been.calledWith 'pandas'

        it 'should bind the queue to the exchange using the routing key', ->
            client.bind 'panda', 'pandas', 'cub.*'
            .then ->
                channel.bindQueue.should.have.been.calledWith 'pandas', 'panda', 'cub.*'

        it 'should declare an anonymous queue when no queue name is supplied', ->
            client.bind('panda', '#', ->).then ->
                channel.assertQueue.should.have.been.calledWith '', { exclusive: true }
                channel.bindQueue.should.have.been.calledWith 'pandas', 'panda', '#'

        it 'should assume an empty routing key if none is given', ->
            client.bind 'panda', 'pandas'
            .then ->
                channel.bindQueue.should.have.been.calledWith 'pandas', 'panda', ''

        it 'should subscribe the callback if one is given', ->
            cb = spy()
            client.bind 'panda', 'pandas', 'cub.*', cb
            .then ->
                channel.consume.should.have.been.calledWith 'pandas', match.func
                channel.consume.firstCall.args[1]({})
                cb.should.have.been.called

        it 'should subscribe the callback if the routing key is omitted', ->
            cb = spy()
            client.bind 'panda', 'pandas', cb
            .then ->
                channel.consume.should.have.been.calledWith 'pandas', match.func
                channel.consume.firstCall.args[1]({})
                cb.should.have.been.called

        it 'should catch exchange errors signalled by amqp, and reject the bind promise', ->
            channel.checkExchange.returns Promise.reject new Error 'Error!'
            client.bind('panda', 'pandas', '#').should.be.rejectedWith 'Error!'

        it 'should catch queue errors signalled by amqp, and reject the bind promise', ->
            channel.checkQueue.returns Promise.reject new Error 'Error!'
            client.bind('panda', 'pandas', '#').should.be.rejectedWith 'Error!'

    describe 'connection error', ->

        it 'should crash the process', ->
            client = new AmqpClient { connection: url: 'amqp://panda' }
            client.channel.then ->
                expect ->
                    conn.emit 'error', new Error("failed badly")
                .to.throw 'failed badly'

        it 'notifies a conf.errorHandler if configured', ->
            handler = spy ->
            client = new AmqpClient { connection:{url:'url'}, errorHandler: handler }
            client.channel.then ->
                conn.emit 'error', new Error("failed badly")
                handler.should.have.been.calledOnce

    describe '.unbind()', ->
        client = undefined
        beforeEach ->
            client = new AmqpClient { connection: url: 'amqp://panda' }

        it 'should unbind the underlying queue', ->
            client.queue('cub').then (q) ->
                spy q, 'unbind'
                client.unbind('cub').then ->
                    q.unbind.should.have.been.calledOnce

        it 'should unsubscribe the underlying queue', ->
            client.queue('cub').then (q) ->
                spy q, 'unsubscribe'
                client.unbind('cub').then ->
                    q.unsubscribe.should.have.been.calledOnce
