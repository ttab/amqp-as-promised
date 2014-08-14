chai   = require 'chai'
Q      = require 'q'
uuid   = require 'uuid'
expect = chai.expect
should = chai.should()

chai.use(require 'sinon-chai')
chai.use(require 'chai-as-promised')
{ spy, stub, mock, match } = require 'sinon'

Rpc = require '../src/rpc'

class Exchange
    publish: ->

class Queue
    subscribe: ->

class Amqpc
    exchange: -> Q new Exchange
    queue: -> Q new Queue

describe 'the Rpc constructor', ->
    amqpc = new Amqpc
    _queue = mock(amqpc).expects('queue').never()
    rpc = new Rpc amqpc

    it 'should not start the return channel', ->
        expect(rpc._returnChannel).to.be.undefined
        _queue.verify

describe 'Rpc.returnChannel()', ->
    channel = new Queue
    _subscribe = mock(channel).expects('subscribe').once()
    amqpc = new Amqpc
    _queue = mock(amqpc).expects('queue').once().returns Q channel

    rpc = new Rpc amqpc

    c1 = rpc.returnChannel()
    c2 = rpc.returnChannel()
    it 'should create a _returnChannel member', ->
        expect(rpc).to.have.property '_returnChannel'
    it 'should call amqpc.queue()', ->
        _queue.verify()
    it 'should add a subscription callback', ->
        _subscribe.verify()
    it 'should return the same value over multiple invocations', ->
        c1.should.eql c2

describe 'the subscription callback', ->
    it 'should in turn invoke resolveResponse()', (done) ->
        channel = new Queue
        channel.subscribe = (callback) ->
            setTimeout (-> callback({}, {}, { correlationId: '1234' })), 100

        amqpc = { queue: -> Q channel }

        rpc = new Rpc amqpc
        rpc.returnChannel()
        rpc.resolveResponse = (corrId, msg) ->
            expect(corrId).to.equal '1234'
            done()

describe 'Rpc.registerResponse()', ->
    rpc = new Rpc new Amqpc

    it 'should have a map of responses', ->
        rpc.should.have.property 'responses'

    def = rpc.registerResponse '1234'

    it 'should return a deferred', ->
        expect(def).to.have.property 'resolve'

    it 'should add a mapping between a corrId and a deferred', ->
        rpc.responses.get('1234').should.eql {def:def,options:{}}

describe 'Rpc.resolveResponse()', ->
    rpc = new Rpc new Amqpc

    def = rpc.registerResponse '1234'
    rpc.resolveResponse '1234', 'hello, world', { header1: 'value1' }

    it 'should resolve the promise', ->
        def.promise.should.eventually.eql 'hello, world'

    it 'should remove the deferred from the response list', ->
        rpc.responses.should.not.have.property '1234'

    it 'should handle non-existant corrIds gracefully', ->
        rpc.resolveResponse '9999', {}

describe 'Rpc response expiration', ->
    rpc = new Rpc new Amqpc, { timeout: 10 }

    it 'should reject the promise with a timeout error', ->
        def = rpc.registerResponse '1234', { info: 'panda.cub' }
        def.promise.should.eventually.be.rejectedWith 'timeout: panda.cub'

    it 'should handle empty expiration events gracefully', ->
        rpc.responses.emit 'expired', undefined

    it 'should handle expiration events that lack a value gracefylly', ->
        rpc.responses.emit 'expired', { }

    it 'should ensure that the expiration event is a deferred before calling reject', ->
        rpc.responses.emit 'expired', { value: { def: reject: 123 } }

describe 'Rpc.rpc() called with headers', ->
    exchange = new Exchange
    _publish = mock(exchange).expects('publish').withArgs 'world', 'msg',
        match({ replyTo: 'q123', headers: { 'customHeader', 'header1' } }).and(match.has('correlationId'))

    queue = new Queue
    queue.name = 'q123'

    amqpc = new Amqpc
    mock(amqpc).expects('queue').returns Q queue
    _exchange = mock(amqpc).expects('exchange').withArgs('hello').returns(Q exchange)

    rpc = new Rpc amqpc
    promise = rpc.rpc('hello', 'world', 'msg', { 'customHeader', 'header1' })

    it 'should return a promise', ->
        promise.should.have.property 'then'
    it 'should call exchange.publish()', ->
        _publish.verify()
    it 'should add exactly one corrId/deferred mapping', ->
        rpc.responses.keys.should.have.length 1
    it 'should use something like a uuid as corrId', ->
        rpc.responses.keys[0].should.match /^\w{8}-/
    it 'should properly resolve the promise with resolveResponse()', ->
        rpc.responses.keys.should.have.length 1
        rpc.resolveResponse rpc.responses.keys[0], 'solved!', {}
        promise.should.eventually.eql('solved!').then ->
            rpc.responses.keys.should.have.length 0

describe 'Rpc.rpc() called without headers', ->
    exchange = new Exchange
    _publish = mock(exchange).expects('publish').withArgs 'world', 'msg',
        match({ replyTo: 'q123' }).and(match (val) -> val.correlationId? and Object.keys(val).indexOf('headers') == -1)

    queue = { name: 'q123' }

    amqpc =
        queue: -> Q queue
        exchange: -> Q exchange

    rpc = new Rpc amqpc
    promise = rpc.rpc('hello', 'world', 'msg')

    it 'should still result in a published message', ->
        _publish.verify()
    it 'should properly resolve the promise with resolveResponse()', ->
        rpc.resolveResponse rpc.responses.keys[0], 'solved!', {}
        promise.should.eventually.eql 'solved!'

describe 'Rpc.rpc() called without msg object', ->
    amqpc =
        queue: -> Q queue
        exchange: -> Q exchange
    rpc = new Rpc amqpc

    it 'should throw an error', ->
        expect(-> rpc.rpc('foo','bar')).to.throw 'Must provide msg'

describe 'Rpc.rpc() called with a timeout option', ->
    amqpc =
        queue: -> Q { name: 'q123' }
        exchange: -> Q new Exchange
    rpc = new Rpc amqpc
    rpc.responses = set:spy()
    spy rpc, 'registerResponse'

    it 'should pass the timeout on to registerResponse()', (done) ->
        rpc.rpc('hello', 'world', 'msg', {}, { timeout: 23 })
        setTimeout ->
            rpc.registerResponse.should.have.been.calledWith match.string,
                {info: "hello/world",timeout: 23}
            done()
        , 10

describe 'Rpc.rpc() called with an info option', (done) ->
    amqpc =
        queue: -> Q { name: 'q123' }
        exchange: -> Q new Exchange
    rpc = new Rpc amqpc
    rpc.responses = set:spy()
    spy rpc, 'registerResponse'

    it 'should pass the info to registerResponse()', (done) ->
        rpc.rpc('hello', 'world', 'msg', {}, { info:'my trace output' })
        setTimeout ->
            rpc.registerResponse.should.have.been.calledWith match.string,
                {info: "my trace output"}
            done()
        , 10
