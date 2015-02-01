Q               = require 'q'
ExchangeWrapper = require '../src/exchange-wrapper'

describe 'ExchangeWrapper', ->
    exchange = wrapper = undefined

    describe 'with options:confirm:true', ->

        beforeEach ->
            exchange = { publish: stub(), options:confirm:true }
            wrapper  = new ExchangeWrapper exchange

        describe '.publish()', ->
            it 'should return a promise', ->
                expect(Q.isPromise(wrapper.publish("routing.key", "msg"))).to.be.true

            it 'should call publish() on the underlying exchange', ->
                exchange.publish.callsArg 3
                wrapper.publish("routing.key", "msg", { my: 'option' }).should.eventually.be.fulfilled
                .then ->
                    exchange.publish.should.have.been.calledWith "routing.key", "msg", { my: 'option' }

            it 'should reject the promise if the underlying exchange signals an error', ->
                exchange.publish.callsArgWith 3, 'error!'
                wrapper.publish("routing.key", "msg", { my: 'option' }).should.eventually.be.rejectedWith 'error!'

    describe 'with no options:confirm:true', ->

        beforeEach ->
            exchange = { publish: stub() }
            wrapper  = new ExchangeWrapper exchange

        describe '.publish()', ->
            it 'should return a promise', ->
                expect(Q.isPromise(wrapper.publish("routing.key", "msg"))).to.be.true

            it 'should call publish() on the underlying exchange', ->
                wrapper.publish("routing.key", "msg", { my: 'option' }).should.eventually.be.fulfilled
                .then ->
                    exchange.publish.should.have.been.calledWith "routing.key", "msg", { my: 'option' }
