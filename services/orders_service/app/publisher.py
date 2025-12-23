import json
import os
import pika

EXCHANGE = "xyz.events"
ROUTING_KEY = "orders.created"

def publish_order_created(order: dict) -> None:
    url = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
    params = pika.URLParameters(url)
    conn = pika.BlockingConnection(params)
    ch = conn.channel()
    ch.exchange_declare(exchange=EXCHANGE, exchange_type="topic", durable=True)

    payload = json.dumps({
        "type": "OrderCreated",
        "data": order,
    }).encode("utf-8")

    ch.basic_publish(exchange=EXCHANGE, routing_key=ROUTING_KEY, body=payload)
    conn.close()
