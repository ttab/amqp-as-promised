declare function amqp(conf: amqp.AmqpConfig): Promise<amqp.AmqpClient>

declare namespace amqp {

    export interface AmqpConfig {
        connection: {
            url: string
        } | {
            host: string
            vhost: string
            login: string
            password: string
        }
        rpc?: {
            timeout?: number
        }
    }

    export interface AmqpClient {
        on(event: 'error', callback: (err: Error) => void): void;
        exchange(name: string | Exchange, opts?: ExchangeOpts): Promise<Exchange>;
        queue<T>(name: string | Queue<T>, opts?: QueueOpts): Promise<Queue<T>>;
        queue<T>(opts: QueueOpts): Promise<Queue<T>>;
        queue<T>(): Promise<Queue<T>>;
        rpc<T>(exchange: string | Exchange, routingKey: string, msg: object | Buffer, headers?: MessageHeaders, opts?: RpcOpts): Promise<T>;
        serve<T>(exchange: string | Exchange, routingKey: string, opts: SubscribeOpts, callback: ServeCallback<T>): void;
        serve<T>(exchange: string | Exchange, routingKey: string, callback: ServeCallback<T>): void;
        bind<T>(exchange: string | Exchange, topic: string, callback: SubscribeCallback<T>): Promise<void>;
        bind<T>(exchange: string | Exchange, queue: string | Queue<T>, topic: string, callback: SubscribeCallback<T>): Promise<void>;
        shutdown(): Promise<void>;
    }

    export interface ExchangeOpts {
        type?: 'topic' | 'fanout' | 'direct' | 'headers'
        passive?: boolean
        durable?: boolean
        autoDelete?: boolean
    }

    export interface QueueArguments {
        [key: string]: string | number | boolean | QueueArguments
    }

    export interface QueueOpts {
        passive?: boolean
        durable?: boolean
        exclusive?: boolean
        autoDelete?: boolean
        arguments?: QueueArguments
    }

    export interface Exchange {
        name: string
        publish: (routingKey: string, message: string | Buffer | object, opts?: PublishOpts)=> Promise<{}>
    }

    export interface MessageOpts {
        expiration?: string
        userId?: string
        priority?: number
        persistent?: boolean
        deliveryMode?: number
        mandatory?: boolean
        immediate?: boolean
        contentType?: string
        contentEncoding?: string
        headers?: MessageHeaders
        correlationId?: string
        replyTo?: string
        messageId?: string
        timestamp?: number
        type?: string
        appId?: string
    }

    export interface PublishOpts extends MessageOpts {
        CC?: string | string[]
        BCC?: string | string[]
    }

    export interface DeliveryInfo extends MessageOpts {
        consumerTag: string
        deliveryTag: number
        redelivered: boolean
        exchange: string
        routingKey: string
    }

    export interface MessageHeaders {
        [key: string]: string | number | boolean | MessageHeaders
    }

    export interface Queue<T> {
        bind(exchange: string | Exchange, topic: string): Promise<Queue<T>>;
        unbind(): Promise<Queue<T>>;
        subscribe(opts: SubscribeOpts, callback: SubscribeCallback<T>): Promise<Queue<T>>;
        subscribe(callback: SubscribeCallback<T>): Promise<Queue<T>>;
        unsubscribe(): Promise<Queue<T>>
        isDurable(): boolean
        isAutoDelete(): boolean
    }

    export interface SubscribeOpts {
        ack?: boolean
        exclusive?: boolean
        prefetchCount?: number
    }

    export interface SubscribeCallback<T> {
        (message: T , headers: MessageHeaders, info: DeliveryInfo, ack: Ack): void
    }

    export interface Ack {
        acknowledge(): void
    }

    export interface RpcOpts {
        info?: string
        timeout?: number
        compress?: boolean
    }

    export interface ServeCallback<T> {
        (message: T, headers: MessageHeaders, info: DeliveryInfo): any
    }
}

export default amqp
