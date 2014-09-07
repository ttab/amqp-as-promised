Changelog
=========

## Unreleased

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
