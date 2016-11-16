deserialize = require '../src/error-deserializer'

describe 'error-deserializer', ->

    it 'returns a non-error payload intact', ->
        payload = { panda : true }
        deserialize(payload).should.eventually.eql payload

    it 'returns an error with message, code and errno, if present', ->
        deserialize { error: { message: 'panda attack!', code: 'EPANDA', errno: -23 } }
        .should.eventually.be.rejected
        .then (err) ->
            err.should.be.instanceOf Error
            err.message.should.equal 'panda attack!'
            err.code.should.equal 'EPANDA'
            err.errno.should.equal -23

    it 'fall backs to using err.toString() if no message, code or errno was found', ->
        deserialize { error: 'panda attack!' }
        .should.eventually.be.rejected
        .then (err) ->
            err.should.be.instanceOf Error
            err.message.should.equal 'panda attack!'
