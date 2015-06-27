Q               = require 'q'
RpcBackend      = require '../src/rpc-backend'

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

    promiseHandler = stub().returns Q.fcall -> 'returnValue'
    inlineHandler  = stub().returns 'returnValue'

    rpc = new RpcBackend {}
    promiseCallback = rpc._mkcallback exchange, promiseHandler
    inlineCallback  = rpc._mkcallback exchange, inlineHandler

    it 'should return callback function', ->
        promiseCallback.should.be.a.func
        inlineCallback.should.be.a.func

    promiseCallback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
    inlineCallback  'msg', { hello: 'world' }, { correlationId: '4321', replyTo: 'reply'}

    it 'when invoked, the callback should in turn invoke the actual handler with msg and headers', ->
        promiseHandler.should.have.been.calledWith 'msg', { hello: 'world' }
    it 'should also support non-promisified functions as handler', ->
        inlineHandler.should.have.been.calledWith 'msg', { hello: 'world' }
    it 'when invoked, the callback should publish to the given exchange', ->
        exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '1234' }
        exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '4321' }

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub().returns Q.fcall -> throw new Error('error msg')

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}

    it 'should pass errors thrown by the handler on to the client', ->
        exchange.publish.should.have.been.calledWith 'reply', { error: 'error msg'}, match.object

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub()

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    callback 'msg', { hello: 'world' }, { correlationId: '1234'}

    it 'should refuse messages without replyTo', ->
        exchange.publish.should.not.have.been.called

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub()

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    callback 'msg', {hello:'world', timeout:1000},
    {correlationId:'1234', replyTo:'reply', timestamp:10}

    it 'should discard timeout messages where timestamp is in info', ->
        exchange.publish.should.not.have.been.called

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub()

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler

    callback 'msg', {hello:'world', timeout:1000, timestamp:'1970-01-01T00:00:00.043Z'},
    {correlationId:'1234', replyTo:'reply'}

    it 'should discard timeout messages where timestamp is in headers', ->
        exchange.publish.should.not.have.been.called
