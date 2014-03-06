chai = require 'chai'
expect = chai.expect
should = chai.should()

Q = require 'q'

chaiAsPromised = require('chai-as-promised')

chai.use chaiAsPromised

describe 'trivial test', ->
    it 'is trivial', ->
        true.should.be.true
