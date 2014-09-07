{EventEmitter} = require 'events'
Q              = require 'q'
QueueWrapper   = require '../src/queue-wrapper'

amqpClient = nodeAmqp = undefined

describe 'QueueWrapper', ->

    beforeEach ->
        nodeAmqp = {}
        amqpClient = proxyquire '../src/amqp-client', 
            'node-amqp': nodeAmqp

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
