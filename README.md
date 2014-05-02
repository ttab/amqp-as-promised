AMQP as Promised
================

![Build Status](https://ci.tt.se/jenkins/buildStatus/icon?job=amqp-as-promised)

Promise wrapper around [node-amqp](https://github.com/postwait/node-amqp).

## Installing

`npm install amqp-as-promised`

## Running

    conf = require './myconf.json' # see example conf below
    amqpc = (require 'amqp-as-promised') conf.amqp

## Config parameters

### `connection`

* Connection settings accepted by
[node-amqp](https://github.com/postwait/node-amqp#connection-options-and-url). You
need to specify either `host`, `vhost`, `login`, `password` or `url`.

### `local`

If true, means there will be no AMQP connection.

### `rpc`

* `timeout`: timeout in ms for rpc calls

## Example config

    {
        "connection": {
            "host": "192.168.0.10",
            "vhost": "test",
            "login": "test",
            "password": "supersecret"
        },
		"local": false,
		"rpc": {
		    "timeout": 2000
		}
    }

## Using `amqpc` to publish

    amqpc.exchange('myexchange').then (ex) ->
        msg = {}
        msg.domain = domain
        ex.publish 'mytopic.foo', msg

## Using `amqpc` to bind

This is shorthand for binding and subscribing.

    amqpc.bind 'myexchange', 'myqueue', 'mytopic.#', (msg, headers, del) ->
        console.log 'received message', msg

To bind an anonymous queue.

    amqpc.bind 'myexchange', '', 'mytopic.#', (msg, headers, del) ->
        console.log 'received message', msg

Or even shorter

    amqpc.bind 'myexchange', 'mytopic.#', (msg, headers, del) ->
        console.log 'received message', msg

To bind the queue to the exchange without subscribing to it, skip the
last parameter (the subscription callback). This is essentially the
same as `queue.bind myexchange, 'mytopic'`, except the exchange and
queue are specified by their names:

    amqpc.bind 'myexchange', 'myqueue', 'mytopic.#'

## Using `amqpc` to get an anomymous queue

To create an anomymous queue.

    amqpc.queue().then (q) -> console.log 'my queue', q

## Using `amqpc` to do RPC-style calls

to send a message to a service that honors the replyTo/correlationId contract:

    amqpc.rpc('myexchange', 'routing.key', msg, [headers], [options]).then (response) ->
        console.log 'received message', response

 * `headers` is an optional parameter holding any custom headers to be
   passed on the RPC service.
 * `options` supports the following settings
   - `timeout` - the timeout in ms for this call



*Note!* In earlier versions the response was an array that included
 the response headers. As of version 0.1, this is no longer the case.

## Using `amqpc` to serve RPC-style calls

To set up a message consumer that automatically honors the
replyTo/correlationId contrat:

    amqpc.serve 'myexchange', 'mytopic.#', (msg, headers, del) ->
        return { result: 'ok' }

The value returned from the handler will be sent back on the queue
specified by the `replyTo` header, with the `correlationId` set.

If an exception is thrown by the handler, it will be propagated back
to the client as an object with a `error` property containing the
error message.

## Shutting down

    graceful = (opts) ->
        log.info 'Shutting down'
        amqpc.shutdown().then ->
            process.exit 0

    process.on 'SIGINT', graceful
    process.on 'SIGTERM', graceful

## The `amqpc` object

### `amqpc.exchange(name, opts)`

A promise for an exchange. If `opts` is omitted declares an exchange in `passive` mode.

### `amqpc.queue(qname, opts)`

A promise for a queue. If `qname` is omitted, `""` is used. If opts is
omitted a default `durable:true` and `autoDelete:(qname=='')`. See
`queue.*` below.

### `amqpc.bind(exname, qname, topic[, callback])`

Shorthand for

1. Looking up exchange for `exname`. Note that `passive:true` so
   exchange must be declared already.
2. Looking up queue for `qname`. See `amqpc.queue` for queue default
   opts.
3. Binding queue to `topic`.
4. Subscribing `callback` to queue (optional).

### `amqpc.shutdown()`

Will unbind all queues and unsubscribe all callbacks then gracefully
shut down the socket connection.

### `amqpc.local`

Read only property that tells whether `conf.local` was true.

### `queue.bind(ex, topic)`

Binds the queue to the given exchange (object, not name). Will unbind
if queue was already bound.

### `queue.unbind()`

Unbinds the queue (if currently bound).

### `queue.subscribe(opts, callback)`

Subscribes the callback to this queue. Will unsubscribe any previous
callback. If opts is omitted, defaults to `ack: false, prefetchCount: 1`

### `queue.unsubscribe()`

Unsubscribes current callback (if any).

### `queue.shift([reject[, requeue]])`

To be used with `queue.subscribe({ack:true}, callback)`. `reject`
rejects the previous message and will requeue it if `requeue` is true.

### `queue.name`

Read only property with the queue name.
