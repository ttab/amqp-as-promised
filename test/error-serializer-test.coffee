
serialize = require '../src/error-serializer'

describe 'error-serializer', ->

    it 'serializes the message', ->
        expect(serialize(new Error 'panda attack!')).to.eql { error: message: 'panda attack!' }

    it 'serializes the code, if present', ->
        e = new Error
        e.code = 'EPANDA'
        expect(serialize(e)).to.eql error: code: 'EPANDA'

    it 'serializes the errno, if present', ->
        e = new Error
        e.errno = -123
        expect(serialize(e)).to.eql error: errno: -123

    it 'falls back to using the original error object if no suitable fields were found', ->
        expect(serialize('panda attack!')).to.eql error: message: 'panda attack!'
