chai           = require 'chai'
expect         = chai.expect
should         = chai.should()
Q              = require 'q'
log            = require 'bog'
chaiAsPromised = require('chai-as-promised')
{ spy, stub, mock, match } = require 'sinon'

chai.use chaiAsPromised

amqpc = require('../src/amqp-client') { local: true }

log.level -1

describe 'QueueWrapper', ->

    describe '.subscribe()', ->
        conn = {}
        queue = {}

        it 'should pass options to .subscribe() on to the wrapped queue', (done) ->
            queue.subscribe = stub().returns { addCallback: (fn) -> fn( { consumerTag: 'tag' }) }
            wrapper = new amqpc._QueueWrapper conn, queue
            wrapper.unsubscribe = stub().returns Q {}

            wrapper.subscribe({panda: true}, ->).then ->
                queue.subscribe.should.have.been.calledWith({panda: true}, match.func)
                done()
            .done()
            
