RpcBackend      = require '../src/rpc-backend'
{gunzipSync, gzipSync} = require 'zlib'

describe 'RpcBackend', ->

    describe '.serve()', ->
        callback = ->
        ex = { name: 'hello' }
        qu = { bind: stub(), subscribe: stub() }
        def = {}

        amqpc =
            exchange: stub()
            queue: stub().returns Promise.resolve qu
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
            qu.subscribe.should.have.been.calledWith match.object, match.func

    describe '._mkcallback()', ->
        exchange = handler = rpc = callback = undefined
        beforeEach ->
            exchange = { publish: stub().returns Promise.resolve() }
            handler = stub().returns Promise.resolve 'returnValue'
            rpc = new RpcBackend {}
            callback = rpc._mkcallback exchange, handler

        it 'should return callback function', ->
            callback.should.be.a 'function'

        it 'when invoked, the callback should in turn invoke the actual handler with msg and headers', ->
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                handler.should.have.been.calledWith 'msg', { hello: 'world' }

        it 'when invoked, the callback should publish to the given exchange', ->
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '1234' }

        it 'should pass errors thrown by the handler on to the client', ->
            handler.returns Promise.reject new Error('error msg')
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', { error: message: 'error msg'}, match.object

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

    describe '._mkcallback()', ->
        exchange = { publish: stub() }

        inlineHandler  = stub().returns 'returnValue'

        rpc = new RpcBackend {}
        inlineCallback  = rpc._mkcallback exchange, inlineHandler

        it 'should return callback function', ->
            inlineCallback.should.be.a 'function'

        inlineCallback  'msg', { hello: 'world' }, { correlationId: '4321', replyTo: 'reply'}

        it 'should support non-promisified functions as handler', ->
            inlineHandler.should.have.been.calledWith 'msg', { hello: 'world' }

        it 'when invoked, the callback should publish to the given exchange', ->
            exchange.publish.should.have.been.calledWith 'reply', 'returnValue', { correlationId: '4321' }

    describe '._mkcallback() with compressed:json', ->

        exchange = handler = rpc = callback = undefined
        beforeEach ->
            exchange = { publish: stub() }
            handler = stub().returns Promise.resolve().then -> return:'panda'
            rpc = new RpcBackend {}
            callback = rpc._mkcallback exchange, handler

        it 'should decompress/deserialize the json to the handler', ->
            v = gzipSync Buffer.from JSON.stringify panda:42
            callback(v, {compress:'json'}, replyTo:'123').then ->
                handler.should.have.been.calledWith panda:42

        it 'should (json) compress the response from the handler', ->
            v = gzipSync Buffer.from JSON.stringify panda:42
            callback(v, {compress:'json'}, replyTo:'123').then ->
                [routingKey, buf] = exchange.publish.args[0]
                routingKey.should.eql '123'
                b2 = gunzipSync buf
                JSON.parse(b2.toString()).should.eql return:'panda'

        it 'should compress the (buffer) response from the handler', ->
            handler = stub().returns Promise.resolve().then -> Buffer.from('panda')
            callback = rpc._mkcallback exchange, handler
            v = gzipSync Buffer.from JSON.stringify panda:42
            callback(v, {compress:'json'}, replyTo:'123').then ->
                [routingKey, buf] = exchange.publish.args[0]
                routingKey.should.eql '123'
                b2 = gunzipSync buf
                b2.toString().should.eql 'panda'

    describe '._mkcallback() with compressed:buffer', ->

        exchange = handler = rpc = callback = undefined
        beforeEach ->
            exchange = { publish: stub() }
            handler = stub().returns Promise.resolve().then -> return:'panda'
            rpc = new RpcBackend {}
            callback = rpc._mkcallback exchange, handler

        it 'should decompress/deserialize the json to the handler', ->
            v = gzipSync Buffer.from('panda')
            callback(v, {compress:'buffer'}, replyTo:'123').then ->
                [buf, headers] = handler.args[0]
                buf.toString().should.eql 'panda'
                expect(headers?.compress).to.eql 'buffer'


    describe '._mkcallback() in ack mode', ->

        exchange = handler = rpc = callback = ack = undefined
        beforeEach ->
            exchange = { publish: stub() }
            handler = stub().returns Promise.resolve().then -> 'retval'
            rpc = new RpcBackend {}
            callback = rpc._mkcallback exchange, handler, {ack:true}
            ack = acknowledge: spy (reject, requeue) ->

        it 'should ack values that handles successfully', ->
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}, ack
            .then ->
                exchange.publish.should.have.been.calledWith 'reply',
                    'retval', match.object
                ack.acknowledge.should.have.been.calledOnce
                ack.acknowledge.args[0].should.eql [false]


        it 'should ack values that has no promise return', ->
            handler = -> 'retval'
            callback = rpc._mkcallback exchange, handler, {ack:true}
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}, ack
            .then ->
                exchange.publish.should.have.been.calledWith 'reply',
                    'retval', match.object
                ack.acknowledge.should.have.been.calledOnce
                ack.acknowledge.args[0].should.eql [false]


        it 'should ack values that handles unsuccessfully', ->
            handler = -> Promise.reject new Error('error msg')
            callback = rpc._mkcallback exchange, handler, {ack:true}
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}, ack
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', { error: message: 'error msg'}, match.object
                ack.acknowledge.should.have.been.calledOnce
                ack.acknowledge.args[0].should.eql [true, false]

        it 'should ack values that throws', ->
            handler = -> throw new Error 'error msg'
            callback = rpc._mkcallback exchange, handler, {ack:true}
            callback 'msg', { hello: 'world' }, { correlationId: '1234', replyTo: 'reply'}, ack
            .then ->
                exchange.publish.should.have.been.calledWith 'reply', { error: message: 'error msg'}, match.object
                ack.acknowledge.should.have.been.calledOnce
                ack.acknowledge.args[0].should.eql [true, false]
