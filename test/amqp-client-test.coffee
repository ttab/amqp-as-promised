{EventEmitter}  = require 'events'
Q               = require 'q'
ExchangeWrapper = require '../src/exchange-wrapper'

amqp = amqpc = amqpClient = nodeAmqp = undefined
            
describe 'AmqpClient', ->

    beforeEach ->
        amqp = new EventEmitter
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
        
