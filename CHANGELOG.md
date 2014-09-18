Changelog
=========

## Unreleased

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
