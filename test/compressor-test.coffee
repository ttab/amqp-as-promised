{compress, decompress} = require '../src/compressor'
{gunzipSync, gzipSync} = require 'zlib'

describe 'compressor', ->

    describe 'compress', ->

        wcomp = (as...) -> Promise.all compress(as...)

        it 'returns [null,Promise(msg)] when no compress prop', ->
            wcomp({panda:42}, null).should.eventually.eql [null, panda:42]

        it 'returns [null,Promise(msg)] when compress prop is false', ->
            wcomp({panda:42}, {compress:false}).should.eventually.eql [null, panda:42]

        it 'returns a compressed buffer and compress:buffer', ->
            wcomp(Buffer.from('panda'), {compress:true}).then ([h, v]) ->
                h.should.eql compress:'buffer'
                Buffer.isBuffer(v).should.eql true
                b = gunzipSync(v)
                b.toString().should.eql 'panda'

        it 'returns a compressed buffer and compress:json', ->
            wcomp({panda:42}, {compress:true}).then ([h, v]) ->
                h.should.eql compress:'json'
                Buffer.isBuffer(v).should.eql true
                b = gunzipSync(v)
                JSON.parse(b.toString()).should.eql panda:42

    describe 'decompress', ->

        wdecomp = (as...) -> Promise.all decompress(as...)

        it 'returns [null,Promise(msg)] when no compress prop', ->
            wdecomp({panda:42}, null).should.eventually.eql [null, panda:42]

        it 'returns [null,Promise(msg)] when compress prop is false', ->
            wdecomp({panda:42}, {compress:false}).should.eventually.eql [null, panda:42]

        it 'decompresses to buffer when compress=buffer', ->
            p = gzipSync(Buffer.from 'panda')
            wdecomp(p, {compress:'buffer'}).then ([h, v]) ->
                h.should.eql 'application/octet-stream'
                Buffer.isBuffer(v).should.eql true
                v.toString().should.eql 'panda'

        it 'decompresses to object when compress=json', ->
            p = gzipSync Buffer.from JSON.stringify panda:42
            wdecomp(p, {compress:'json'}).then ([h, v]) ->
                h.should.eql 'application/json'
                v.should.eql panda:42

        it 'fails on bad decompressions', ->
            p = Buffer.from('not correct gzip')
            wdecomp p, {compress:'buffer'}
            .catch (err) ->
                err.toString().should.eql 'Error: incorrect header check'

        it 'fails on bad JSON deserialization', ->
            p = gzipSync Buffer.from('not correct json')
            wdecomp p, {compress:'json'}
            .catch (err) ->
                err.toString()[0...29].should.eql 'SyntaxError: Unexpected token'
