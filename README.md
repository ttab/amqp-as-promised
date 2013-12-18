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

* Connection settings for RabbitMQ. `host`, `vhost`, `login`,
             `password` specifies how to connect.
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

    amqpc.bind 'myexchange', 'mytopic.#', (msg, headers, del) ->
        console.log 'received message', msg

## Using `amqpc` to create an anonymous queue

    amqpc.queue('').then (q) ->
	    console.log 'queue created: ' + q.name

## Shutting down

    graceful = (opts) ->
        log.info 'Shutting down'
        amqpc.shutdown().then ->
            process.exit 0

    process.on 'SIGINT', graceful
    process.on 'SIGTERM', graceful
