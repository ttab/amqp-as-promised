Q    = require 'q'
zlib = require 'zlib'

plug = (rs, rj) -> (err, res) -> if err then rj(err) else rs(res)
comp   = (buf) -> Q.Promise (rs, rj) -> zlib.gzip   buf, plug(rs, rj)
decomp = (buf) -> Q.Promise (rs, rj) -> zlib.gunzip buf, plug(rs, rj)
jsonp  = (str) -> Q.Promise (rs, rj) -> try rs(JSON.parse str) catch err then rj(err)

I    = (v) -> v

compress = (msg, props) ->
    if props?.compress
        if Buffer.isBuffer(msg)
            [{compress:'buffer'}, comp msg]
        else
            [{compress:'json'}, comp Buffer JSON.stringify msg]
    else
        [null, Q(msg)]


decompress = (msg, props) ->
    if props?.compress
        data = msg?.data ? msg
        if props.compress == 'buffer'
            ['application/octet-stream', decomp(data)]
        else if props.compress == 'json'
            ['application/json', decomp(data).then (buf) -> jsonp buf.toString()]
        else
            [null, Q(msg)]
    else
        [null, Q(msg)]


module.exports = {compress, decompress}
