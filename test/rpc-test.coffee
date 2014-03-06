chai            = require 'chai'
chaiAsPromised  = require 'chai-as-promised'
mochaAsPromised = require 'mocha-as-promised'
sinon           = require 'sinon'
sinonChai       = require 'sinon-chai'
Q               = require 'q'
uuid            = require 'uuid'

expect = chai.expect
should = chai.should()
chai.use chaiAsPromised
chai.use sinonChai
mochaAsPromised()

Rpc = require '../src/rpc'

class Exchange
    publish: ->

class Queue
    subscribe: ->

class Amqpc
    exchange: -> Q.fcall -> new Exchange
    queue: -> Q.fcall -> new Queue

describe 'the Rpc constructor', ->
    amqpc = new Amqpc
    _queue = sinon.mock(amqpc).expects('queue').never()
    rpc = new Rpc amqpc

    it 'should not start the return channel', ->
        expect(rpc._returnChannel).to.be.undefined
        _queue.verify

describe 'Rpc.returnChannel()', ->
    channel = new Queue
    _subscribe = sinon.mock(channel).expects('subscribe').once()
    amqpc = new Amqpc
    _queue = sinon.mock(amqpc).expects('queue').once().returns Q.fcall -> channel

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

        amqpc = { queue: -> Q.fcall -> channel }

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
        rpc.responses.should.have.property '1234', def

describe 'Rpc.resolveResponse()', ->
    rpc = new Rpc new Amqpc

    def = rpc.registerResponse '1234'
    rpc.resolveResponse '1234', 'hello, world', { header1: 'value1' }

    it 'should resolve the promise', ->
        def.promise.should.eventually.eql [ 'hello, world', { header1: 'value1' } ]

    it 'should remove the deferred from the response list', ->
        rpc.responses.should.not.have.property '1234'

    it 'should handle non-existand corrIds gracefully', ->
        rpc.resolveResponse '9999', {}

describe 'Rpc.rpc() called with headers', ->
    exchange = new Exchange
    _publish = sinon.mock(exchange).expects('publish').withArgs 'world', 'msg',
        sinon.match({ replyTo: 'q123', headers: { 'customHeader', 'header1' } }).and(sinon.match.has('correlationId'))

    queue = new Queue
    queue.name = 'q123'

    amqpc = new Amqpc
    sinon.mock(amqpc).expects('queue').returns Q.fcall -> queue
    _exchange = sinon.mock(amqpc).expects('exchange').withArgs('hello').returns(Q.fcall -> exchange)

    rpc = new Rpc amqpc
    promise = rpc.rpc('hello', 'world', 'msg', { 'customHeader', 'header1' })

    it 'should return a promise', ->
        promise.should.have.property 'then'
    it 'should call exchange.publish()', ->
        _publish.verify()
    it 'should add exactly one corrId/deferred mapping', ->
        Object.keys(rpc.responses).should.have.length 1
    it 'should use something like a uuid as corrId', ->
        Object.keys(rpc.responses)[0].should.match /^\w{8}-/
    it 'should properly resolve the promise with resolveResponse()', ->
        rpc.resolveResponse Object.keys(rpc.responses)[0], 'solved!', {}
        promise.should.eventually.eql [ 'solved!', {} ]

describe 'Rpc.rpc() called without headers', ->
    exchange = new Exchange
    _publish = sinon.mock(exchange).expects('publish').withArgs 'world', 'msg',
        sinon.match({ replyTo: 'q123' }).and(sinon.match (val) -> val.correlationId? and Object.keys(val).indexOf('headers') == -1)

    queue = { name: 'q123' }

    amqpc =
        queue: -> Q.fcall -> queue
        exchange: -> Q.fcall -> exchange

    rpc = new Rpc amqpc
    promise = rpc.rpc('hello', 'world', 'msg')

    it 'should still result in a published message', ->
        _publish.verify()
    it 'should properly resolve the promise with resolveResponse()', ->
        rpc.resolveResponse Object.keys(rpc.responses)[0], 'solved!', {}
        promise.should.eventually.eql [ 'solved!', {} ]

describe 'Rpc.rpc() called without msg object', ->

    amqpc =
        queue: -> Q.fcall -> queue
        exchange: -> Q.fcall -> exchange

    rpc = new Rpc amqpc

    it 'should throw an error', ->
        expect(-> rpc.rpc('foo','bar')).to.throw 'Must provide msg'
