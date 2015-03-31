Q               = require 'q'
RpcBackend      = require '../src/rpc-backend'

describe 'RpcBackend', ->

    describe '.serve()', ->
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

    describe '._mkcallback()', ->
        exchange = handler = rpc = callback = undefined
        beforeEach ->
            exchange = { publish: stub() }
            handler = stub().returns Q.fcall -> 'returnValue'
            rpc = new RpcBackend {}
            callback = rpc._mkcallback exchange, handler

        it 'should return callback function', ->
            callback.should.be.a.func

        it 'when invoked, the callback should in turn invoke the actual handler with msg and headers', ->
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                handler.should.have.been.calledWith 'msg', { hello: 'world' }

        it 'when invoked, the callback should publish to the given exchange', ->
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '1234' }

        it 'should pass errors thrown by the handler on to the client', ->
            handler.returns Q.fcall -> throw new Error('error msg')
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', { error: 'error msg'}, match.object

        it 'should refuse messages without replyTo', ->
            expect(callback 'msg', { hello: 'world' }, { correlationId: '1234'}).to.be.undefined
            handler.should.not.have.been.called
            exchange.publish.should.not.have.been.called

        it 'should discard timeout messages where timestamp is in info', ->
            expect(callback 'msg', {hello:'world', timeout:1000}, {correlationId:'1234', replyTo:'reply', timestamp:10}).to.be.undefined
            handler.should.not.have.been.called
            exchange.publish.should.not.have.been.called

        it 'should discard timeout messages where timestamp is in headers', ->
            expect(callback 'msg', {hello:'world', timeout:1000, timestamp:'1970-01-01T00:00:00.043Z'}, {correlationId:'1234', replyTo:'reply'}).to.be.undefined
            handler.should.not.have.been.called
            exchange.publish.should.not.have.been.called

        it 'should handle errors in exchange.publish', ->
            exchange.publish.throws new Error 'such fail!'
            callback('msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'})
                .should.eventually.be.undefined

        it 'should invoke the handler with a progress callback', ->
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                handler.should.have.been.calledWith match.string, match.object, match.func

        it 'when invoked, the progress callback should publish progress messages', ->
            handler = (msg, headers, progress) ->
                Q.fcall ->
                    progress 'such progress! (1)'
                .then ->
                    progress 'such progress! (2)'
                    return 'returnValues'
            callback = rpc._mkcallback exchange, handler

            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', 'such progress! (1)', { correlationId: '1234#x-progress:0' }
                exchange.publish.should.have.been.calledWith 'reply', 'such progress! (2)', { correlationId: '1234#x-progress:1' }
                exchange.publish.should.have.been.calledWith 'reply', 'returnValues', { correlationId: '1234' }

    describe '._mkcallback()', ->
        exchange = { publish: stub() }

        inlineHandler  = stub().returns 'returnValue'

        rpc = new RpcBackend {}
        inlineCallback  = rpc._mkcallback exchange, inlineHandler

        it 'should return callback function', ->
            inlineCallback.should.be.a.func

        inlineCallback  'msg', { hello: 'world' }, { correlationId: '4321', replyTo: 'reply'}

        it 'should support non-promisified functions as handler', ->
            inlineHandler.should.have.been.calledWith 'msg', { hello: 'world' }
        it 'when invoked, the callback should publish to the given exchange', ->
            exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '4321' }
