
describe 'Index', ->
    amqpc = Rpc = index = bog = undefined
    beforeEach ->
        amqpc = stub().returns {
            connect: ->
                Promise.resolve("ok")
        }
        Rpc   = spy()
        bog   = level: spy()
        index = proxyquire '../src/index', {
            './amqp-client': amqpc
            './rpc': Rpc
            'bog': bog
        }

    it 'should handle setting log level', ->
        cfg =
            host: 'host'
            vhost: 'vhost'
            logLevel: 'warn'
        index cfg
        bog.level.should.have.been.calledWith 'warn'

    it 'should support new-style config', ->
        cfg =
            connection:
                url: 'url'
            rpc:
                timeout: 1234
        index cfg
        amqpc.should.have.been.calledWith cfg

    it 'should support old-style config', ->
        cfg =
            host: 'host'
            vhost: 'vhost'
        index cfg
        amqpc.should.have.been.calledWith { connection: { host: 'host', vhost: 'vhost' } }

    it 'exposes RpcError', ->
        index.should.have.property 'RpcError'
