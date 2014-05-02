chai            = require 'chai'
Q               = require 'q'
log             = require 'bog'
RpcBackend      = require '../src/rpc-backend'

{ assert, spy, match, mock, stub } = require 'sinon'

expect = chai.expect
should = chai.should()
chai.use(require 'chai-as-promised')
chai.use(require 'sinon-chai')

describe 'RpcBackend.serve()', ->
    callback = ->
    ex = { name: 'hello' }
    qu = { bind: stub(), subscribe: stub() }
    def = {}

    amqpc =
        exchange: stub()
        queue: stub().returns Q.fcall -> qu
        bind: stub()

    amqpc.exchange.withArgs('hello').returns(ex).withArgs('').returns(def)

    rpc = new RpcBackend amqpc

    it 'should return a promise', ->
        (rpc.serve 'hello', 'world', callback).should.be.fulfilled
    it 'should create the named exchange', ->
        amqpc.exchange.should.have.been.calledWith 'hello', { type: 'topic', durable: true, autoDelete: false }
    it 'should fetch the default exchange', ->
        amqpc.exchange.should.have.been.calledWith ''
    it 'should create a request queue', ->
        amqpc.queue.should.have.been.calledWith 'hello.world', { durable: true, autoDelete: false }
    it 'should bind the exchange to the queue', ->
        qu.bind.should.have.been.calledWith ex, 'world'
    it 'should subscribe the callback to the request queue', ->
        qu.subscribe.should.have.been.calledWith match.func


describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub().returns Q.fcall -> 'returnValue'

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    it 'should return callback function', ->
        callback.should.be.a.func

    callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}

    it 'when invoked, the callback should in turn invoke the actual handler with msg and headers', ->
        handler.should.have.been.calledWith 'msg', { hello: 'world' }
    it 'when invoked, the callback should publish to the given exchange', ->
        exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '1234' }

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub().returns Q.fcall -> throw new Error('error msg')
    _error = log.error
    log.error = ->

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}

    it 'should pass errors thrown by the handler on to the client', ->
        exchange.publish.should.have.been.calledWith 'reply', { error: 'error msg'}, match.object
        log.error = _error

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub()

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    callback 'msg', { hello: 'world' }, { correlationId: '1234'}

    it 'should refuse messages without replyTo', ->
        exchange.publish.should.not.have.been.called
