from flask import Flask, jsonify, request
import time
import os


app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.get("/ok")
def ok():
    return jsonify({"message": "upstream ok"}), 200


@app.get("/users")
def users():
    return jsonify({"users": [{"id": 1, "name": "Alice"}]}), 200


@app.get("/products")
def products():
    return jsonify({"products": [{"id": 10, "name": "Widget"}]}), 200


@app.get("/slow")
def slow():
    time.sleep(2)
    return jsonify({"message": "slow response"}), 200


@app.get("/fail")
def fail():
    return jsonify({"error": "intentional failure"}), 500


@app.route("/echo", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
def echo():
    return (
        jsonify({
            "method": request.method,
            "headers": {k: v for k, v in request.headers.items()},
            "args": request.args.to_dict(),
        }),
        200,
    )


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5001"))
    app.run(host="0.0.0.0", port=port)
