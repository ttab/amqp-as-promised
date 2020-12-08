Changelog
=========

# 5.3.1 - 2020-12-08

  * Bug fix: RpcError was missing from the TypeScript declarations

# 5.3.0 - 2020-10-23

  * Now use Loglevel instead of Bog for logging

# 5.2.3 - 2020-09-28

  * Bug fix: there was an error in the typescript definition for `serve()`

## 5.2.2 - 2020-07-07

  * Bug fix: the `topic` argument for `exchange()` is optional. 
  * Any method that accept an exhange or queue name string also
    accepts an exchange or queue object, respectively.

## 5.2.1 - 2020-05-20

  * Added missing TypeScript definitions for `queue.bind()`

## 5.2.0 - 2020-05-19

  * Added TypeScript definitions.

## 5.1.0 - 2018-11-30

  * Bug fix: since 2.0 the intention has always been to throw an
    exception on underlying connection errors. This has not worked
    properly recently, making error handling hard. This release fixes
    that.
  * It is now possible to attach a proper event handler to listen to
    `error` events.
  * Stopped using `new Buffer()` in favor of `Buffer.from()`
  * Dependencies have been updated, to avoid `npm audit` problems.
  
## 5.0.2 - 2018-11-29

  * Bug fix: publish() didn't wait for the write buffer to drain.

## 5.0.1 - 2018-08-07

  * Bug fix: publish() didn't reject properly if the client was
    shutting down.

## 5.0.0 - 2018-07-31

  * Improved shutdown handling. 
  * Syntax to access the library has been changed to improve
    connection management. See [Running](README.md#running) for
    details.

## 4.2.0 - 2018-01-30

  * `setMaxListeners()` on the created channel in order to avoid
    misleading memory leak warnings.

## 4.1.1 - 2016-12-14

  * Bug fix: publish() returned prematurely if the write buffer was full

## 4.1.0 - 2016-12-05

 * `waitForConnection` feature to wait for rabbitmq server to become
   available. This is not a reconnect feature.

## 4.0.3 - 2016-12-01

 * Fixed inconsistent backwards compatibility for non-JSON payloads.

## 4.0.1 - 2016-11-28

 * Expose `RpcError` as an exported class.

## 4.0.0 - 2016-11-18

 * Improved error handling:
   1. `RpcBackend.serve()` will now serialize errors in a slightly different
      format, preserving `message`, `code` and `errno` if present in
      the error object.
   2. `Rpc.rpc()` will treat any return message that is a JSON object
      containing an `error` property as a remote error, resulting in a
      rejected promise. Previously we didn't care to inspect return
      messages, so remote errors would still yield fulfilled promises.

## 3.0.2 - 2016-11-08

 * Bug fix: didn't provide backwards compatible promises for `rpc()`

## 3.0.1 - 2016-11-02

 * Bug fix: didn't support `text/plain` payloads correctly.

## 3.0.0 - 2016-10-19

 * The underlying amqp library has changed from `node-amqp` to
   `amqplib`. Efforts have been made to keep everything as backwards
   compatible as possible.
 * Local mode is no longer supported.
 * `queue.shift()` is no longer supported.
 * `Q` has been dropped in favor of native promises. As a result,
   support for promise progress notifications over RPC is no longer
   supported.

## 0.3.0 - 2015-01-29
 * TTL is now set on RPC messages.

## 0.2.2 - 2014-09-18
 * Bugfix: clumsy typo in rpc.

## 0.2.1 - 2014-09-18

### Changed
 * Better error handling in `amqpc.queue()`, `amqpc.exchange()` and
   `amqpc.bind()`; errors caught during queue and exchange declaration
   will now properly reject the promise.
 * Bug fix in `amqpc.bind()`: omitting the queue name didn't work as
   advertised in version 0.2.0, but should be fine now.

## 0.2.0 - 2014-09-08

### Changed
 * `exchange.publish()` now returns a promise, as
   advertised. Previously it did not, even though the docs said so.
 * The defaults for `amqpc.queue()` have changed to be more intuitive
   and in line with how `amqpc.exchange()` works.
 * `amqpc.bind()`, which previously expected an exchange name and a
   queue name, now accepts both names or exchange/queue objects.
 * `queue.bind()`, which previously expected an exchange object, not
   accepts both a name or an object.

## 0.1.6

### Changed
 * Use non-persistent `deliveryMode` for RPC calls.

## 0.1.5

#### Changed
 * Now uses `node-amqp` 0.2.0 under the hood.
 * Better handling of reconnects.
