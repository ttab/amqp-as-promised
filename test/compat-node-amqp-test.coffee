compat = require '../src/compat-node-amqp'

describe 'node-ampq compatibility', ->

    describe '.connection()', ->

        it 'should use the url, if present', ->
            compat.connection
                connection:
                    url: 'amqp://panda/cub'
            .should.eql [ 'amqp://panda/cub' ]

        it 'should construct an url from parts if necessary', ->
            compat.connection
                connection:
                    host: 'panda'
                    vhost: 'cub'
                    login: 'user'
                    password: 'pass'
            .should.eql [ 'amqp://user:pass@panda/cub' ]

    describe '.callback()', ->
        client = channel = undefined
        beforeEach ->
            channel =
                ack: stub().returns Promise.resolve()

        it 'should deserialize the payload if it is text/json', ->
            cb = spy()
            compat.callback(channel, cb)
                properties: { contentType: 'text/json' }
                fields: {}
                content: Buffer.from('{"hello": "world"}')
            cb.should.have.been.calledWith { 'hello': 'world' }, match.object, match.object

        it 'should deserialize the payload if it is application/json', ->
            cb = spy()
            compat.callback(channel, cb)
                properties: { contentType: 'application/json' }
                fields: {}
                content: Buffer.from('{"hello": "world"}')
            cb.should.have.been.calledWith { 'hello': 'world' }, match.object, match.object

        it 'should handle other content types', ->
            cb = spy()
            buf = Buffer.from('hello, world')
            compat.callback(channel, cb)
                properties: { contentType: 'application/octet-stream' }
                fields: {}
                content: buf
            cb.should.have.been.calledWith { data: buf, contentType: 'application/octet-stream' }

        it 'should handle text/plain like regular payloads', ->
            cb = spy()
            buf = Buffer.from('hello, world')
            compat.callback(channel, cb)
                properties: { contentType: 'text/plain' }
                fields: {}
                content: buf
            cb.should.have.been.calledWith { data: buf, contentType: 'text/plain' }

        it 'should suppply an ack object', ->
            data =
                properties: { }
                fields: {}
                content: Buffer.from('panda')
            cb = spy()
            compat.callback(channel, cb) data
            cb.should.have.been.calledWith match.any, match.object, match.object, match acknowledge: match.func
            cb.firstCall.args[3].acknowledge()
            .then ->
                channel.ack.should.have.been.calledWith data


    describe '.exchangeArgs()', ->

        it 'should return just the name if passive=true', ->
            compat.exchangeArgs('panda', { passive: true })
            .should.deep.eql [ 'panda' ]

        it 'should assume durable=false if not specified', ->
            compat.exchangeArgs('panda', { autoDelete: true })
            .should.deep.eql [ 'panda', 'topic', { durable: false, autoDelete: true }]

        it 'should assume type=topic if not specified in opts', ->
            compat.exchangeArgs('panda', { durable: true })
            .should.deep.eql [ 'panda', 'topic', { durable: true }]

        it 'should respect type specified in opts', ->
            compat.exchangeArgs('panda', { durable: true, type: 'direct' })
            .should.deep.eql [ 'panda', 'direct', { durable: true }]

        it 'should not assume a type if no options were given', ->
            compat.exchangeArgs('panda', {})
            .should.deep.eql [ 'panda' ]

        it 'should not assume a type if no options were specified', ->
            compat.exchangeArgs('panda')
            .should.deep.eql [ 'panda' ]

    describe '.subscribeOpts()', ->

        it 'should assume noAck=true', ->
            compat.subscribeOpts({ }).should.have.property 'noAck', true

        it 'should translate ack to noAck', ->
            compat.subscribeOpts({ ack: true }).should.have.property 'noAck', false
            compat.subscribeOpts({ ack: false }).should.have.property 'noAck', true


    describe '.publishArgs()', ->

        it 'should publish the message', ->
            buf = Buffer.from('panda')
            [ key, msg, opts ] = compat.publishArgs 'cub', buf, {}
            key.should.eql 'cub'
            msg.should.eql buf
            opts.should.have.property 'contentType', 'application/octet-stream'

        it 'should bufferize plain text messages', ->
            [ key, msg, opts ] = compat.publishArgs 'cub', 'panda', {}
            key.should.eql 'cub'
            msg.should.be.instanceof Buffer
            opts.should.have.property 'contentType', 'application/octet-stream'

        it 'should serialize objects as json', ->
            [ key, msg, opts ] = compat.publishArgs 'cub', { panda: true }, {}
            key.should.eql 'cub'
            msg.should.be.instanceof Buffer
            opts.should.have.property 'contentType', 'application/json'
