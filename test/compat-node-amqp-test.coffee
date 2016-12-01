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
            client =
                channel: Promise.resolve channel

        it 'should deserialize the payload if it is text/json', ->
            cb = spy()
            compat.callback(client, cb)
                properties: { contentType: 'text/json' }
                fields: {}
                content: new Buffer('{"hello": "world"}')
            cb.should.have.been.calledWith { 'hello': 'world' }, match.object, match.object

        it 'should deserialize the payload if it is application/json', ->
            cb = spy()
            compat.callback(client, cb)
                properties: { contentType: 'application/json' }
                fields: {}
                content: new Buffer('{"hello": "world"}')
            cb.should.have.been.calledWith { 'hello': 'world' }, match.object, match.object

        it 'should handle text/plain payloads', ->
            cb = spy()
            compat.callback(client, cb)
                properties: { contentType: 'text/plain' }
                fields: {}
                content: new Buffer('hello, world')
            cb.should.have.been.calledWith 'hello, world'

        it 'should handle other content types', ->
            cb = spy()
            buf = new Buffer('hello, world')
            compat.callback(client, cb)
                properties: { contentType: 'application/octet-stream' }
                fields: {}
                content: buf
            cb.should.have.been.calledWith { data: buf, contentType: 'application/octet-stream' }

        it 'should suppply an ack object', ->
            data =
                properties: { }
                fields: {}
                content: new Buffer('panda')
            cb = spy()
            compat.callback(client, cb) data
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
