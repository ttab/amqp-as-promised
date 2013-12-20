chai = require 'chai'
expect = chai.expect
should = chai.should()

Q = require 'q'

chaiAsPromised = require('chai-as-promised')

chai.use chaiAsPromised

describe 'trivial test', ->
	it 'is trivial', ->
		true.should.be.true

# describe 'promise', ->
# 	it 'is known', (done) ->
# 		fn = (a, b) ->
# 			def = Q.defer()
# 			setTimeout (-> def.resolve a + b), 100
# 			def.promise
			
# 		fn(2, 2).should.be.fulfilled.and.notify.done
