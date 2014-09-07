{EventEmitter}  = require 'events'
Q               = require 'q'
QueueWrapper    = require '../src/queue-wrapper'
ExchangeWrapper = require '../src/exchange-wrapper'

amqp = amqpc = amqpClient = nodeAmqp = undefined
            
describe 'AmqpClient', ->

    beforeEach ->
        amqp = new EventEmitter
        queue = new EventEmitter
        amqp.queue = (name, obts, cb) ->
            cb queue
            queue.emit 'open'
        amqp.exchange = (name, opts, cb) -> cb {}
        nodeAmqp = { createConnection: stub().returns amqp }
        amqpClient = proxyquire '../src/amqp-client', 
            'amqp': nodeAmqp
        amqpc = amqpClient { connection: url: 'url' }
        amqp.emit 'ready'

    describe 'conn', ->
        it 'should invoke amqp.createConnection with the connection parameters', ->
            amqpc.exchange('panda').then ->
                nodeAmqp.createConnection.should.have.been.calledWith { url: 'url' }

    describe '.queue()', ->
        beforeEach ->
            spy amqp, 'queue'

        it 'should assume exclusive:true when called without name and opts', ->
            amqpc.queue().then ->
                amqp.queue.should.have.been.calledWith '', { exclusive: true }
        it 'should assume passive:true when called with name but without opts', ->
            amqpc.queue('panda').then ->
                amqp.queue.should.have.been.calledWith 'panda', { passive:true }
        it 'should pass given name and opts on when creating the queue', ->
            amqpc.queue('panda', { my: 'option' }).then ->
                amqp.queue.should.have.been.calledWith 'panda', { my: 'option' }

        it 'should returns a promise for a QueueWrapper', ->
            amqpc.queue().should.eventually.be.an.instanceof QueueWrapper
    
    describe '.exchange()', ->
        beforeEach ->
            spy amqp, 'exchange'
            
        describe 'should set the confirm flag when creating an exchange', ->
            it 'with explicit options', ->
                amqpc.exchange('panda', { durable: true }).then ->
                    amqp.exchange.should.have.been.calledWith 'panda', { durable: true, confirm: true }
            it 'without explicit options', ->
                amqpc.exchange('panda').then ->
                    amqp.exchange.should.have.been.calledWith 'panda', { passive: true, confirm: true }

        it 'should return an ExchangeWrapper', ->
            amqpc.exchange('panda').should.eventually.be.an.instanceof ExchangeWrapper
        
