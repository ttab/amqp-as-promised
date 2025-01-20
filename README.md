AMQP as Promised
================

![Version](http://img.shields.io/npm/v/amqp-as-promised.svg) &nbsp;
![License](http://img.shields.io/npm/l/amqp-as-promised.svg) &nbsp;
![Monthly downloads](http://img.shields.io/npm/dm/amqp-as-promised.svg) &nbsp;
![Build Status](https://ci2.tt.se/buildStatus/icon\?job\=ttab/amqp-as-promised/master)

A high-level [promise-based](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises) API built on
[`amqplib`](https://www.npmjs.com/package/amqplib)
extended with functions for AMQP-based RPC.

* [`amqplib` API docs][amqplib-api-docs]
* Old versions of this package were based on [node-amqp][npm-node-amqp].

  [amqplib-api-docs]: http://www.squaremobius.net/amqp.node/channel_api.html
  [npm-node-amqp]: https://github.com/postwait/node-amqp

## Table of contents

 * [Configuration](#configuration)
 * [Examples](#examples)
 * [API](#api)
   * [The amqpc object](#the-amqpc-object)
   * [The exchange object](#the-exchange-object)
   * [The queue object](#the-queue-object)
   * [RPC functions](#rpc-functions)
 * [Changelog](CHANGELOG.md)

## Version Notes

#### 5.0

Syntax to access the library has been changed in 5.0 to improve
connection management. See the [Running](#running)-section for
instructions.

#### 3.0

The underlying amqp library was changed from
`node-amqp` to `amqplib`. Efforts have been made to keep everything as
backwards compatible as possible, but some things have changed:

 * Local mode is no longer supported.
 * `queue.shift()` is no longer supported.
 * `Q` has been dropped in favor of native promises. As a result,
   support for promise progress notifications over RPC is no longer
   supported.

## Installing

`npm install amqp-as-promised`

## Running

5.0+
```coffee
    conf = require './myconf.json' # see example conf below
    ((require 'amqp-as-promised') conf.amqp).then (amqpc) ->
```

Earlier versions
```coffee
    conf = require './myconf.json' # see example conf below
    amqpc = (require 'amqp-as-promised') conf.amqp
```

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

### `rpc`

* `timeout`: timeout in ms for rpc calls. Default: 1000ms


### `publisherConfirm`

*Since 5.7.0*

 * `publisherConfirm`: boolean that enables or disables the RabbitMQ
    [Publisher Confirms](https://www.rabbitmq.com/docs/confirms) extension.
    Default: false.

### `logLevel`

* `logLevel`: sets the log level. Defaults to `INFO`. Possible levels
  are `DEBUG`, `INFO`, `WARN`, `ERROR`

### `errorHandler`

*Since 2.0.0* connection errors are rethrown to crash process. 

* `errorHandler`: sets a handler function to receive the error instead
of throwing to process. This option is deprecated, as a better way to
do this is to attach an `error` event handler.

### `waitForConnection`

*Since 4.1.0*

* `waitForConnection`: on startup, keeps retrying to connect until
  successful. Will not attempt reconnect after established connection.

## Example config

    {
        "connection": {
            "host": "192.168.0.10",
            "vhost": "test",
            "login": "test",
            "password": "supersecret"
        },
        "publisherConfirm": true,
        "logLevel": "warn",
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


Events
=======

Amqp-as-promised emits `error` events on unexpected network errors,
for example then the connection to the server has been lost. It is up
to the client to handle these errors, as amqp-as-promised doesn't
reconnect automatically. Keep in mind that error recovery can be
tricky, and the best option might be to just crash and restart the
application on error.

This is a simple but effective error handler:

```coffee
amqpc.on 'error', (err) ->
    console.log err
    process.exit 1
```

## Unhandled errors

If there are no error handlers attached (either using `amqp.on()` or
setting the `errorHandler` in the configuration), amqp-as-promised
will as a last resort throw the error. This will most likely result in
an application crash unless there is an uncaught exception handler set
on the `process`.

Examples
==========

## Using `amqpc` to publish

```coffee
amqpc.exchange('myexchange').then (ex) ->
    msg = {}
    msg.domain = domain
    ex.publish('mytopic.foo', msg).then ->
        console.log 'published message!'
```

## Using `amqpc` to bind

This is shorthand for binding and subscribing.

```coffee
amqpc.bind 'myexchange', 'myqueue', 'mytopic.#', (msg, headers, del) ->
    console.log 'received message', msg
```

To bind an anonymous queue.

    amqpc.bind 'myexchange', '', 'mytopic.#', (msg, headers, del) ->
        console.log 'received message', msg

Or even shorter

```coffee
amqpc.bind 'myexchange', 'mytopic.#', (msg, headers, del) ->
    console.log 'received message', msg
```

To bind the queue to the exchange without subscribing to it, skip the
last parameter (the subscription callback). This is essentially the
same as `queue.bind myexchange, 'mytopic'`, except the exchange and
queue are specified by their names:

```coffee
amqpc.bind 'myexchange', 'myqueue', 'mytopic.#'
```

## Using `amqpc` to get an anomymous queue

To create an anomymous queue.

```coffee
amqpc.queue().then (q) -> console.log 'my queue', q
```

## Using `amqpc` to do RPC-style calls

to send a message to a service that honors the replyTo/correlationId contract:


```coffee
amqpc.rpc('myexchange', 'routing.key', msg, [headers], [options]).then (response) ->
    console.log 'received message', response
```

 * `headers` is an optional parameter holding any custom headers to be
   passed on the RPC service.
 * `options` supports the following settings
   - `timeout` - the timeout in ms for this call



*Note!* In earlier versions the response was an array that included
 the response headers. As of version 0.1.0, this is no longer the case.

## Using `amqpc` to serve RPC-style calls

To set up a message consumer that automatically honors the
replyTo/correlationId contract:

```coffee
amqpc.serve 'myexchange', 'mytopic.#', (msg, headers, del) ->
    return { result: 'ok' }
```

The value returned from the handler will be sent back on the queue
specified by the `replyTo` header, with the `correlationId` set.

If an exception is thrown by the handler, it will be propagated back
to the client as an object:
```
{
  "error": {
    "message": <exception.message>,
    [ "code": <exception.code>, ]
    [ "errno": <exception.errno> ]
  }
}
```

### Serve with prefetchCount/ack

To rate limit the rpc calls to 5 concurrent, we use an options object
to set `{ack:true, prefetchCount:5}`.

Notice that the message acking is handled by the rpc backend wrapper.

```coffee
amqpc.serve 'myexchange', 'mytopic.#', {ack:true, prefetchCount:5}, (msg, headers, del) ->
    return { result: 'ok' }
```

## Shutting down

```coffee
graceful = (opts) ->
    log.info 'Shutting down'
    amqpc.shutdown().then ->
        process.exit 0

process.on 'SIGINT', graceful
process.on 'SIGTERM', graceful
```

API
===

## The `amqpc` object

### `amqpc.on(event, handler)`

Attach an event handler. Currently only `error` events are supported.

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

### `amqpc.bind(exchange, queue, topic[, callback])`

Shorthand for

1. If `exchange` is a string, then look up the existing exchange with
   that name.
2. If `queue` is a string, then look up the existing queue with that name.
3. Bind queue to `exchange/topic`.
4. Subscribe `callback` to queue (optional).

#### Parameters

 * `exchange` - an exchange object or a string with the name of an
   exchange
 * `queue` - a queue object or a string with the name of a queue
 * `topic` - a string with the topic name.
 * `callback` - see `queue.subscribe` below.


### `amqpc.shutdown()`

Will unbind all queues and unsubscribe all callbacks then gracefully
shut down the socket connection.

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

The callback will be called with arguments `(msg, headers, deliveryinfo,
actions)`, where `actions` is an object that holds these methods:

  * `acknowledge()`: returns a Promise to acknowledge the message. This is
    only relevant if `opts.ack` is false (which is the default).

### `queue.unsubscribe()`

Unsubscribes current callback (if any).

### `queue.name`

Read only property with the queue name.

## RPC functions

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
    timeout, the promise is instead rejected. Replies that are JSON
    objects that have an `error` property set are assumed to be remote
    errors, and will result in a rejected promise.

#### Parameters

 * `exchange` - the name of an exchange, or an exchange object
 * `routingkey`
 * `headers` - AMQP headers to be sent with the message. See [exchange.publish()](#exchangepublishroutingkey-msg-options).
 * `options` - valid options are:
   + `timeout` - timeout in milliseconds. If none is specified, the
     default value specified when creating the client is used.
   + `compress` - set to `true` to use [payload compression](#compression)

### Compression

*Since 0.4.0*

The RPC mechanism has a transparent payload gzip compression of JSON
objects Buffer. When activated both request and response are
compressed. To activate, the rpc client must ask for compression by setting
the `compress` option.

Example

```coffee
amqpc.rpc('myexchange', 'routing.key', msg, [headers], {compress:true}).then (response) ->
    console.log 'received message', response
```

