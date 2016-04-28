Q = require 'q'
{compress, decompress} = require '../src/compressor'
{gunzipSync, gzipSync} = require 'zlib'

describe 'compressor', ->

    describe 'compress', ->

        wcomp = (as...) -> Q.all compress(as...)

        it 'returns [null,Q(msg)] when no compress prop', ->
            wcomp({panda:42}, null).should.eventually.eql [null, panda:42]

        it 'returns [null,Q(msg)] when compress prop is false', ->
            wcomp({panda:42}, {compress:false}).should.eventually.eql [null, panda:42]

        it 'returns a compressed buffer and compress:buffer', ->
            wcomp(Buffer('panda'), {compress:true}).spread (h, v) ->
                h.should.eql compress:'buffer'
                Buffer.isBuffer(v).should.eql true
                b = gunzipSync(v)
                b.toString().should.eql 'panda'

        it 'returns a compressed buffer and compress:json', ->
            wcomp({panda:42}, {compress:true}).spread (h, v) ->
                h.should.eql compress:'json'
                Buffer.isBuffer(v).should.eql true
                b = gunzipSync(v)
                JSON.parse(b.toString()).should.eql panda:42

    describe 'decompress', ->

        wdecomp = (as...) -> Q.all decompress(as...)

        it 'returns [null,Q(msg)] when no compress prop', ->
            wdecomp({panda:42}, null).should.eventually.eql [null, panda:42]

        it 'returns [null,Q(msg)] when compress prop is false', ->
            wdecomp({panda:42}, {compress:false}).should.eventually.eql [null, panda:42]

        it 'decompresses to buffer when compress=buffer', ->
            p = gzipSync(Buffer 'panda')
            wdecomp(p, {compress:'buffer'}).spread (h, v) ->
                h.should.eql 'application/octet-stream'
                Buffer.isBuffer(v).should.eql true
                v.toString().should.eql 'panda'

        it 'decompresses to object when compress=json', ->
            p = gzipSync Buffer JSON.stringify panda:42
            wdecomp(p, {compress:'json'}).spread (h, v) ->
                h.should.eql 'application/json'
                v.should.eql panda:42

        it 'fails on bad decompressions', ->
            p = Buffer('not correct gzip')
            wdecomp p, {compress:'buffer'}
            .catch (err) ->
                err.toString().should.eql 'Error: incorrect header check'

        it 'fails on bad JSON deserialization', ->
            p = gzipSync Buffer('not correct json')
            wdecomp p, {compress:'json'}
            .catch (err) ->
                err.toString()[0...31].should.eql 'SyntaxError: Unexpected token o'
