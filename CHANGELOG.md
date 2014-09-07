Changelog
=========

## master

 * `exchange.publish()` now returns a promise, instead of being just an
   async call.
 * The defaults for `amqpc.queue()` have changed to be more intuitive
   and in line with how `amqpc.exchange()` works.

## 0.1.6

 * Use non-persistent `deliveryMode` for RPC calls.

## 0.1.5

 * Now uses `node-amqp` 0.2.0 under the hood.
 * Better handling of reconnects.
