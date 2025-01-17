uuid = require 'uuid'
Rpc  = require '../src/rpc'
{gunzipSync, gzipSync} = require 'zlib'

describe 'Rpc', ->
    amqpc = exchange = queue = rpc = undefined
    beforeEach ->
        exchange =
            publish: stub().returns Promise.resolve()
            name: 'hello'
        queue =
            subscribe: stub()
        amqpc =
            exchange: stub().returns Promise.resolve exchange
            queue: stub().returns Promise.resolve queue
            compat: require '../src/compat-node-amqp'
        rpc = new Rpc amqpc

    describe '.constructor()', ->

        it 'should not start the return channel (yet)', ->
            expect(rpc._returnChannel).to.be.undefined

    describe '.returnChannel()', ->

        it 'should create a _returnChannel member', ->
            rpc.returnChannel().then ->
                expect(rpc).to.have.property '_returnChannel'

        it 'should call amqpc.queue()', ->
            rpc.returnChannel().then ->
                amqpc.queue.should.have.been.calledOnce

        it 'should add a subscription callback', ->
            rpc.returnChannel().then ->
                queue.subscribe.should.have.been.calledOnce

        it 'should return the same value over multiple invocations', ->
            Promise.all([
                rpc.returnChannel()
                rpc.returnChannel()
            ]).then ([c1, c2]) ->
                c1.should.equal c2

        describe 'the subscription callback', ->

            it 'should in turn invoke resolveResponse()', (done) ->
                queue.subscribe = (callback) ->
                    setImmediate (-> callback({}, {}, { correlationId: '1234' }))
                rpc.resolveResponse = (corrId, msg) ->
                    expect(corrId).to.equal '1234'
                    done()
                rpc.returnChannel()
                return undefined

    describe '.registerResponse()', ->
        def = deserialize = undefined
        beforeEach ->
            deserialize = ->
            def = rpc.registerResponse '1234', {}, deserialize
        afterEach ->
            def.promise.catch ->

        it 'should have a map of responses', ->
            rpc.should.have.property 'responses'

        it 'should return a deferred', ->
            expect(def).to.have.property 'resolve'

        it 'should add a mapping between a corrId and a deferred', ->
            rpc.responses.get('1234').should.eql
                def         : def
                options     : {}
                deserialize : deserialize

    describe '.resolveResponse()', ->

        describe 'with a regular corrId', ->
            def = undefined
            beforeEach ->
                def = rpc.registerResponse '1234'
                rpc.resolveResponse '1234', 'hello, world', { header1: 'value1' }

            it 'should resolve the promise', ->
                def.promise.should.eventually.eql 'hello, world'

            it 'should remove the deferred from the response list', ->
                expect(rpc.responses.get('1234')).to.be.null

            it 'should handle non-existant corrIds gracefully', ->
                rpc.resolveResponse '9999', {}

        describe 'with a compress:json header', ->

            it 'decompresses/deserializes object', ->
                def = rpc.registerResponse '1234'
                buf = gzipSync Buffer.from JSON.stringify panda:42
                rpc.resolveResponse '1234', buf, compress:'json'
                def.promise.then (res) ->
                    res.should.eql panda:42

            it 'rejects failed decompression', ->
                def = rpc.registerResponse '1234'
                buf = Buffer.from('so wrong') # this is not valid gzip
                rpc.resolveResponse '1234', buf, compress:'json'
                def.promise.should.eventually.be.rejectedWith 'incorrect header check'

            it 'rejects failed deserialization', ->
                def = rpc.registerResponse '1234'
                buf = gzipSync Buffer.from('so wrong') # this is not valid json
                rpc.resolveResponse '1234', buf, compress:'json'
                def.promise.should.eventually.be.rejectedWith 'Unexpected token'

        describe 'with a compress:buffer header', ->

            it 'decompresses buffer', ->
                def = rpc.registerResponse '1234'
                buf = gzipSync Buffer.from('panda')
                rpc.resolveResponse '1234', buf, compress:'buffer'
                def.promise.then (res) ->
                    res.toString().should.eql 'panda'

        describe 'with an error payload', ->

            it 'returns a rejection', ->
                def = rpc.registerResponse '1234'
                rpc.resolveResponse '1234', { error: { message: 'panda attack!', code: 'EPANDA' }}
                def.promise.should.eventually.be.rejectedWith('panda attack!')
                    .and.have.property 'code', 'EPANDA'

    describe 'response expiration', ->
        beforeEach ->
            rpc = new Rpc amqpc, { timeout: 10 }

        it 'should reject the promise with a timeout error', ->
            def = rpc.registerResponse '1234', { info: 'panda.cub' }
            def.promise.should.eventually.be.rejectedWith 'timeout: panda.cub'

        it 'should handle empty expiration events gracefully', ->
            rpc.responses.emit 'expired', undefined

        it 'should handle expiration events that lack a value gracefylly', ->
            rpc.responses.emit 'expired', { }

        it 'should ensure that the expiration event is a deferred before calling reject', ->
            rpc.responses.emit 'expired', { value: { def: reject: 123 } }

    describe '.rpc()', ->

        describe 'callled with headers', ->
            beforeEach ->
                queue.name = 'q123'
                rpc = new Rpc amqpc, { timeout: 500 }

            it 'should return a promise', ->
                promise = rpc.rpc('hello', 'world', 'msg', { 'myHeader1':42 }, timestamp:new Date(42)).catch ->
                promise.should.have.property 'then'

            it 'should call exchange.publish()', ->
                rpc.rpc('hello', 'world', 'msg', { 'myHeader1':42 }, timestamp:new Date(42)).catch ->
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    exchange.publish.should.have.been.calledOnce
                    exchange.publish.should.have.been.calledWith 'world', 'msg',
                        match
                            replyTo:'q123',
                            headers:
                                timeout:'500',
                                myHeader1:42,
                        .and(match.has('correlationId')).and(match(deliveryMode:1))

            it 'should add exactly one corrId/deferred mapping', ->
                rpc.rpc('hello', 'world', 'msg', { 'myHeader1':42 }, timestamp:new Date(42)).catch ->
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    rpc.responses.keys.should.have.length 1

            it 'should use something like a uuid as corrId', ->
                rpc.rpc('hello', 'world', 'msg', { 'myHeader1':42 }, timestamp:new Date(42)).catch ->
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    rpc.responses.keys[0].should.match /^\w{8}-/

            it 'should properly resolve the promise with resolveResponse()', ->
                promise = rpc.rpc('hello', 'world', 'msg', { 'myHeader1':42 }, timestamp:new Date(42)).catch ->
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    rpc.responses.keys.should.have.length 1
                    rpc.resolveResponse rpc.responses.keys[0], 'solved!', {}
                    promise.should.eventually.eql('solved!').then ->
                        rpc.responses.keys.should.have.length 0

        describe 'called without headers', ->
            beforeEach ->
                queue.name = 'q123'
                rpc = new Rpc amqpc, { timeout: 501 }

            it 'should still result in a published message', ->
                rpc.rpc('hello', 'world', 'msg', undefined, timestamp:new Date(43)).catch ->
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    exchange.publish.should.have.been.calledWith 'world', 'msg',
                        match
                            replyTo:'q123'
                            headers:
                                timeout:'501'
                        .and(match (val) -> val.correlationId?)

            it 'should properly resolve the promise with resolveResponse()', ->
                promise = rpc.rpc('hello', 'world', 'msg', undefined, timestamp:new Date(43)).catch ->
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    rpc.resolveResponse rpc.responses.keys[0], 'solved!', {}
                    promise.should.eventually.eql 'solved!'

        describe 'called without msg object', ->

            it 'should throw an error', ->
                expect(-> rpc.rpc('foo','bar')).to.throw 'Must provide msg'

        describe 'should set message TTL', ->

            it 'with the default timeout if none is specified', ->
                rpc = new Rpc amqpc
                stub(rpc, 'registerResponse').returns Promise.resolve()
                rpc.timeout.should.equal 1000
                rpc.rpc('foo', 'bar', {}).then ->
                    exchange.publish.should.have.been.calledWith 'bar', {},
                        match headers: match timeout: '1000'

        describe 'called with a timeout option', ->
            beforeEach ->
                stub(rpc, 'registerResponse').returns Promise.resolve()

            it 'should pass the timeout on to registerResponse()', ->
                rpc.rpc('hello', 'world', 'msg', {}, { timeout: 23 })
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    rpc.registerResponse.should.have.been.calledWith match.string,
                        {info: "hello/world",timeout: 23}

            it 'should pass the info to registerResponse()', ->
                rpc.rpc('hello', 'world', 'msg', {}, { info:'my trace output' })
                (new Promise((rs) -> setTimeout rs, 1)).then ->
                    rpc.registerResponse.should.have.been.calledWith match.string,
                        {info: "my trace output"}

        describe 'called with compress option', ->

            beforeEach ->
                rpc.registerResponse = -> Promise.resolve()

            describe 'and json', ->

                it 'should publish compressed object and set compress header', ->
                    rpc.rpc 'hello', 'world', panda:42, null, compress:true
                    .then ->
                        [routingKey, buf, opts] = exchange.publish.args[0]
                        routingKey.should.eql 'world'
                        b2 = gunzipSync buf
                        JSON.parse(b2.toString()).should.eql panda:42
                        expect(opts?.headers?.compress).to.eql 'json'

            describe 'and buffer', ->

                it 'should publish compressed buffer and set compress header', ->
                    rpc.rpc 'hello', 'world', Buffer.from('panda'), null, compress:true
                    .then ->
                        [routingKey, buf, opts] = exchange.publish.args[0]
                        routingKey.should.eql 'world'
                        b2 = gunzipSync buf
                        b2.toString().should.eql 'panda'
                        expect(opts?.headers?.compress).to.eql 'buffer'
