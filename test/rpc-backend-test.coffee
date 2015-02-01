Q               = require 'q'
RpcBackend      = require '../src/rpc-backend'

describe 'RpcBackend.serve()', ->
    rpc = amqpc = serve = callback = ex = qu = def = null

    beforeEach ->
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

    describe 'without opts', ->

        beforeEach ->
            serve = rpc.serve 'hello', 'world', callback
        it 'should return a promise', ->
            serve.should.be.fulfilled
        it 'should create the named exchange', ->
            amqpc.exchange.should.have.been.calledWith 'hello', { type: 'topic', durable: true, autoDelete: false }
        it 'should fetch the default exchange', ->
            amqpc.exchange.should.have.been.calledWith ''
        it 'should create a request queue', ->
            amqpc.queue.should.have.been.calledWith 'hello.world', { durable: true, autoDelete: false }
        it 'should bind the exchange to the queue', ->
            qu.bind.should.have.been.calledWith ex, 'world'
        it 'should subscribe the callback to the request queue', ->
            qu.subscribe.should.have.been.calledWith {}, match.func


    describe 'with opts', ->

        beforeEach ->
            serve = rpc.serve 'hello', 'world', {
                ack:true
                prefetchCount: 10
                goja:42
            }, callback

        it 'can take an opts object with ack/prefetchCount', ->
            qu.subscribe.should.have.been.calledWith {ack:true,prefetchCount:10}, match.func

describe 'RpcBackend._mkcallback()', ->
    exchange = { publish: stub() }
    handler = stub().returns Q.fcall -> 'returnValue'

    rpc = new RpcBackend {}
    ack = acknowledge:spy()
    callback = rpc._mkcallback exchange, handler, ack

    it 'should return callback function', ->
        callback.should.be.a.func

    callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}

    it 'when invoked, the callback should in turn invoke the actual handler with msg and headers', ->
        handler.should.have.been.calledWith 'msg', { hello: 'world' }
    it 'when invoked, the callback should publish to the given exchange', ->
        exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '1234' }

    it 'should not invoke ack when not ack:true', ->
        ack.acknowledge.should.not.have.been.calledOnce

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


describe 'RpcBackend._mkcallback() with ack:true', ->
    exchange = { publish: stub() }
    handler = stub().returns Q.fcall -> 'returnValue'

    rpc = new RpcBackend {}
    ack = acknowledge:spy()
    callback = rpc._mkcallback exchange, handler, {ack:true}
    ack = acknowledge:spy()

    it 'should return callback function', ->
        callback.should.be.a.func

    callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}, ack

    it 'when invoked, the callback should in turn invoke the actual handler with msg and headers', ->
        handler.should.have.been.calledWith 'msg', { hello: 'world' }
    it 'when invoked, the callback should publish to the given exchange', ->
        exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '1234' }

    it 'should invoke ack.acknowledge', ->
        ack.acknowledge.should.have.been.calledOnce

describe 'RpcBackend._mkcallback() with ack:true', ->
    exchange = { publish: stub() }
    handler = stub().returns Q.fcall -> throw new Error('error msg')

    rpc = new RpcBackend {}
    callback = rpc._mkcallback exchange, handler, {ack:true}
    ack = acknowledge:spy()

    callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}, ack

    it 'should pass errors thrown by the handler on to the client', ->
        exchange.publish.should.have.been.calledWith 'reply', { error: 'error msg'}, match.object

    it 'should invoke ack.acknowledge', ->
        ack.acknowledge.should.have.been.calledOnce
