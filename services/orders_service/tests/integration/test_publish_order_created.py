import json
import os
import pika
from testcontainers.rabbitmq import RabbitMqContainer
from services.orders_service.app.publisher import publish_order_created, EXCHANGE, ROUTING_KEY


def _consume_one(url: str, queue: str) -> dict:
    conn = pika.BlockingConnection(pika.URLParameters(url))
    ch = conn.channel()
    method, _, body = ch.basic_get(queue=queue, auto_ack=True)
    conn.close()
    assert method is not None, "Expected at least one message"
    return json.loads(body.decode("utf-8"))


def test_publish_order_created_to_rabbitmq():
    with RabbitMqContainer("rabbitmq:3.13-management") as rabbit:
        # Construct the AMQP URL manually
        host = rabbit.get_container_host_ip()
        port = rabbit.get_exposed_port(5672)
        url = f"amqp://guest:guest@{host}:{port}/"
        os.environ["RABBITMQ_URL"] = url

        # Bind a test queue to the exchange/routing key
        conn = pika.BlockingConnection(pika.URLParameters(url))
        ch = conn.channel()
        ch.exchange_declare(exchange=EXCHANGE, exchange_type="topic", durable=True)
        q = ch.queue_declare(queue="", exclusive=True).method.queue
        ch.queue_bind(queue=q, exchange=EXCHANGE, routing_key=ROUTING_KEY)
        conn.close()

        publish_order_created({"order_id": "o-1", "sku": "SKU-123", "qty": 2})
        msg = _consume_one(url, q)

        assert msg["type"] == "OrderCreated"
        assert msg["data"]["order_id"] == "o-1"
