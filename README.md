AMQP as Promised
================

![Version](http://img.shields.io/npm/v/amqp-as-promised.svg)
![Monthly downloads](http://img.shields.io/npm/dm/amqp-as-promised.svg)
![Build Status](https://ci.tt.se/jenkins/buildStatus/icon?job=amqp-as-promised)

A high-level [promise-based](https://github.com/kriskowal/q) API built on
[node-amqp](https://github.com/postwait/node-amqp), extended with
functions for AMQP-based RPC.

 * [Configuration](#configuration)
 * [Examples](#examples)
 * [API](#api)
   * [The amqpc object](#the-amqpc-object)
   * [The exchange object](#the-exchange-object)
   * [The queue object](#the-queue-object)

## Installing

`npm install amqp-as-promised`

## Running

    conf = require './myconf.json' # see example conf below
    amqpc = (require 'amqp-as-promised') conf.amqp

## Configuration

As of version 0.1.0, the following config parameters are accepted,
although we also try to keep backwards compatibility with the older
format.

### `connection`

Connection settings accepted by
[node-amqp](https://github.com/postwait/node-amqp#connection-options-and-url). You
need to at minimum specify either
* `host`
* `vhost`
* `login`
* `password`

or
* `url`.

### `local`

If true, means there will be no AMQP connection. Default: false

### `rpc`

* `timeout`: timeout in ms for rpc calls. Default: 1000ms

### `logLevel`

* `logLevel`: sets the log level. Defaults to `INFO`. Possible levels
  are `DEBUG`, `INFO`, `WARN`, `ERROR`

## Example config

    {
        "connection": {
            "host": "192.168.0.10",
            "vhost": "test",
            "login": "test",
            "password": "supersecret"
        },
        "logLevel": "warn",
        "local": false,
        "rpc": {
            "timeout": 2000
        }
    }

Or with url:

    {
        "connection": {
            "url": "amqp://myuser:supersecret@192.168.0.10/test"
        },
        "logLevel": "warn"
    }


Examples
==========

## Using `amqpc` to publish

    amqpc.exchange('myexchange').then (ex) ->
        msg = {}
        msg.domain = domain
        ex.publish('mytopic.foo', msg).then ->
			console.log 'published message!'

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
 the response headers. As of version 0.1.0, this is no longer the case.

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

API
===

## The `amqpc` object

### `amqpc.exchange(name, opts)`

A promise for an exchange. If `opts` is omitted, then `passive:true`
is assumed.

### `amqpc.queue(qname, opts)`

A promise for a queue. If `qname` is omitted, `""` is used. If opts is
omitted, then `exclusive:true` is assumed if the name is empty, or
`passive:true` if not.

Thus, `amqpc.queue()` will create a new exclusive, anonymous, queue
that is automatically deleted on disconnect, while
`amqpc.queue('my-queue')` will try to passively declare the existing
queue `my-queue`.

See [`queue.*`](#the-queue-object) below.

### `amqpc.bind(exchange, qname, topic[, callback])`

Shorthand for

1. Looking up exchange for `exname`. Note that `passive:true` so
   exchange must be declared already.
2. Looking up queue for `qname`. See `amqpc.queue` for queue default
   opts.
3. Binding queue to `topic`.
4. Subscribing `callback` to queue (optional).

#### Parameters

 * `exchange` - an exchange object or a string with the name of an
   exchange
 * `queue` - a queue object or a string with the name of a queue
 * `topic`
 * `callback`

### `amqpc.shutdown()`

Will unbind all queues and unsubscribe all callbacks then gracefully
shut down the socket connection.

### `amqpc.local`

Read only property that tells whether `conf.local` was true.

## The `exchange` object

### `exchange.publish(routingKey, msg, options)`

Publishes a message, returning a promise.

## The `queue` object

### `queue.bind(exchange, topic)`

Binds the queue to the given exchange (object, or string). Will unbind
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

## RPC

### `amqpc.rpc(exchange, routingKey, msg, [headers], [options])`

Perform an AMQP-based remote procedure call, and returns a promise for
the return value:

 1. Creates an exlusive, anonymous, return queue if doesn't already
    exist.
 2. Publishes an RPC-style message on the given `exchange`, with the
    specified `routingkey`, `headers` and `options`. The `replyTo` and
    `correlationId` headers are set automatically.
 3. Waits for a reply on the return queue, and resolves the promise
    with the contents of the reply. If no reply is received before the
    timeout, the promise is instead rejected.

#### Parameters

 * `exchange` - the name of an exchange, or an exchange object
 * `routingkey`
 * `headers` - AMQP headers to be sent with the message. See [exchange.publish()](#exchangepublishroutingkey-msg-options).
 * `options` - valid options are:
   + `timeout` - timeout in milliseconds. If none is specified, the
     default value specified when creating the client is used.
