{EventEmitter} = require 'events'
Q              = require 'q'

amqpClient = nodeAmqp = undefined
            
describe 'AmqpClient', ->

    beforeEach ->
        nodeAmqp = {}
        amqpClient = proxyquire '../src/amqp-client', 
            'amqp': nodeAmqp

    describe 'conn', ->

        it 'should invoke amqp.createConnection with the connection parameters', ->
            amqp = new EventEmitter
            amqp.exchange = (name, opts, cb) -> cb {}
            nodeAmqp.createConnection = stub().returns amqp
            amqpc = amqpClient { connection: url: 'url' }
            amqp.emit 'ready'
            amqpc.exchange('panda').then ->
                nodeAmqp.createConnection.should.have.been.calledWith { url: 'url' }
