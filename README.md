AMQP as Promised
================

Promise wrapper around [node-amqp](https://github.com/postwait/node-amqp).

## Installing

`npm install amqp-as-promised`

## Running

    conf = require './myconf.json' # see example conf below
    amqpc = (require 'amqp-as-promised') conf.amqp

## Config parameters

### `amqp`

* Connection settings for RabbitMQ. `host`, `vhost`, `login`, `password` specifies how to connect.
* `local`: means there will be no AMQP connection.

## Example localhost config `conf-localhost.json`

    {
        "amqp": {
            "host": "192.168.0.10",
            "vhost": "test",
            "login": "test",
            "password": "supersecret"
        },
    }

## Using `amqpc` to publish

    amqpc.exchange('myexchange').then (ex) ->
        msg = {}
        msg.domain = domain
        ex.publish 'mytopic.foo', msg

## Using `amqpc` to bind

This is shorthand for binding and subscribing.

    amqpc.bind 'myexchange', 'mytopic.#', (msg, headers, del) ->
        console.log 'received message', msg

## Using `amqpc` to get an anomymous queue

To create an anomymous queue.

    amqpc.queue().then (q) -> console.log 'my queue', q

To create an anonymous queue shorthand.

    amqpc.bind('myexchange', '', 'mytopic.#').then (q) ->
	    console.log 'queue created: ' + q.name

Or even shorter

    amqpc.bind('myexchange', 'mytopic.#').then (q) ->
	    console.log 'queue created: ' + q.name

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

### `amqpc.bind(exname, qname, topic, callback)`

Shorthand for

1. Looking up exchange for `exname`. Note that `passive:true` so
   exchange must be declared already.
2. Looking up queue for `qname`. See `amqpc.queue` for queue default
   opts.
3. Binding queue to `topic`.
4. Subscribing `callback` to queue.

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
