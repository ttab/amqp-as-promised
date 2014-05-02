proxyquire = require 'proxyquire'
chai       = require 'chai'
expect     = chai.expect
should     = chai.should()

chai.use(require 'sinon-chai')
{ spy, stub, mock, match } = require 'sinon'

describe 'Index', ->
    amqpc = Rpc = index = undefined
    beforeEach ->
        amqpc = stub().returns {}
        Rpc   = spy()
        index = proxyquire '../src/index', {
            './amqp-client': amqpc
            './rpc': Rpc
        }

    it 'should support new-style config', ->
        cfg = 
            connection: 
                url: 'url'
            rpc:
                timeout: 1234
        index cfg
        amqpc.should.have.been.calledWith cfg
        Rpc.should.have.been.calledWith match.object, { timeout: 1234 } 

    it 'should support old-style config', ->
        cfg = 
            host: 'host'
            vhost: 'vhost'
        index cfg
        amqpc.should.have.been.calledWith { connection: { host: 'host', vhost: 'vhost' }, local: undefined }
        Rpc.should.have.been.calledWith match.object

    it 'should honor the local property of old-style config', ->
        cfg = 
            local: true
        index cfg
        amqpc.should.have.been.calledWith { connection: match.object, local: true }
        Rpc.should.have.been.calledWith match.object
        
