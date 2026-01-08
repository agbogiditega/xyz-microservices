import os
import json
import time
import subprocess
import httpx
import pika
from testcontainers.rabbitmq import RabbitMqContainer

EXCHANGE = "xyz.events"

def wait_http(url: str, timeout_s: int = 20):
    start = time.time()
    while time.time() - start < timeout_s:
        try:
            r = httpx.get(url, timeout=1.0)
            if r.status_code < 500:
                return
        except Exception:
            pass
        time.sleep(0.5)
    raise RuntimeError(f"Service not ready: {url}")

def test_e2e_order_created_event():
    with RabbitMqContainer("rabbitmq:3.13-management") as rabbit:
        # Construct the AMQP URL manually
        host = rabbit.get_container_host_ip()
        port = rabbit.get_exposed_port(5672)
        rabbit_url = f"amqp://guest:guest@{host}:{port}/"

        env = os.environ.copy()
        env["RABBITMQ_URL"] = rabbit_url

        # Start orders-service (example: uvicorn)
        proc = subprocess.Popen(
            ["python", "-m", "uvicorn", "orders_service.app.main:app", "--port", "8010"],
            cwd="services/orders_service",
            env=env,
        )
        try:
            wait_http("http://127.0.0.1:8010/docs")

            # bind queue to all events for assertion
            conn = pika.BlockingConnection(pika.URLParameters(rabbit_url))
            ch = conn.channel()
            ch.exchange_declare(exchange=EXCHANGE, exchange_type="topic", durable=True)
            q = ch.queue_declare(queue="", exclusive=True).method.queue
            ch.queue_bind(queue=q, exchange=EXCHANGE, routing_key="#")
            # Keep connection open to preserve exclusive queue

            # call REST endpoint
            r = httpx.post("http://127.0.0.1:8010/orders", json={"sku": "SKU-123", "qty": 1})
            r.raise_for_status()

            # assert at least one event arrives (reuse same channel)
            method, _, body = ch.basic_get(queue=q, auto_ack=True)
            conn.close()

            assert method is not None
            msg = json.loads(body.decode("utf-8"))
            assert msg["type"] == "OrderCreated"
        finally:
            proc.terminate()
            proc.wait(timeout=10)
