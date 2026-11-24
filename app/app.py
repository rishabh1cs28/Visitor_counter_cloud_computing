import os, socket
import redis
from flask import Flask, jsonify

app = Flask(__name__)

raw_port = os.getenv("REDIS_PORT", "6379")
if ":" in raw_port:
    raw_port = raw_port.split(":")[-1]
try:
    redis_port = int(raw_port)
except ValueError:
    redis_port = 6379

r = redis.Redis(host=os.getenv("REDIS_HOST", "redis"),
                port=redis_port,
                socket_connect_timeout=2, decode_responses=True)
CLUSTER = os.getenv("CLUSTER_NAME", "local")

@app.route("/")
def index():
    count = r.incr("visits")
    return (f"<h1>Visitor Counter</h1><p>Visits: <b>{count}</b></p>"
            f"<p>Served by pod: {socket.gethostname()} | cluster: {CLUSTER}</p>")

@app.route("/healthz")
def healthz():
    try:
        r.ping()
        return jsonify(status="ok"), 200
    except redis.RedisError:
        return jsonify(status="redis-down"), 503

@app.route("/burn")
def burn():  # CPU-heavy endpoint for HPA load test
    x = 0
    for i in range(2_000_000):
        x += i * i
    return jsonify(done=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
