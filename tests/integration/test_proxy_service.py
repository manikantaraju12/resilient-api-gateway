import sys
sys.path.insert(0, "/app")

from fastapi.testclient import TestClient
import importlib


def create_app_with_fakes(monkeypatch):
    # Reload to ensure clean state
    for mod in list(sys.modules.keys()):
        if mod.startswith("src"):
            del sys.modules[mod]

    # Use fakeredis for both limiter and breaker
    import fakeredis
    fake = fakeredis.FakeRedis(decode_responses=True)
    
    # Import and patch before creating app
    import src.services.rate_limiter
    import src.services.circuit_breaker
    import src.routes.proxy_routes
    
    src.services.rate_limiter.get_redis_client = lambda: fake
    src.services.circuit_breaker.get_redis_client = lambda: fake

    # Patch httpx.AsyncClient.request to simulate upstream
    async def fake_request(self, method, url, headers=None, content=None):
        from httpx import Response
        if url.endswith("/ok"):
            return Response(200, headers={"X-Upstream": "ok"}, content=b'{"message":"ok"}')
        if url.endswith("/fail"):
            return Response(500, headers={"X-Upstream": "fail"}, content=b'{"error":"fail"}')
        return Response(200, content=b"{}")

    import httpx
    original_request = httpx.AsyncClient.request
    httpx.AsyncClient.request = fake_request
    
    try:
        main = importlib.import_module("src.main")
        app = main.create_app()
        return app
    finally:
        httpx.AsyncClient.request = original_request


def test_health_endpoint(monkeypatch):
    app = create_app_with_fakes(monkeypatch)
    client = TestClient(app)
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "healthy"


def test_proxy_success(monkeypatch):
    from src.config.settings import settings
    settings.UPSTREAM_URL = "http://upstream-service:5001"

    app = create_app_with_fakes(monkeypatch)
    client = TestClient(app)
    r = client.get("/proxy/ok")
    assert r.status_code == 200
    assert r.headers.get("X-Upstream") == "ok"


def test_rate_limit_429(monkeypatch):
    from src.config.settings import settings
    settings.RATE_LIMIT_CAPACITY = 1
    settings.RATE_LIMIT_REFILL_RATE = 1.0
    settings.UPSTREAM_URL = "http://upstream-service:5001"

    app = create_app_with_fakes(monkeypatch)
    client = TestClient(app)
    # First allowed
    r1 = client.get("/proxy/ok")
    assert r1.status_code == 200
    # Second should be rate limited
    r2 = client.get("/proxy/ok")
    assert r2.status_code == 429
    assert r2.headers.get("Retry-After") is not None


def test_circuit_breaker_503(monkeypatch):
    from src.config.settings import settings
    settings.CIRCUIT_BREAKER_FAILURE_THRESHOLD = 1
    settings.UPSTREAM_URL = "http://upstream-service:5001"

    app = create_app_with_fakes(monkeypatch)
    client = TestClient(app)
    # First fail triggers OPEN
    r1 = client.get("/proxy/fail")
    assert r1.status_code == 500
    # Next request blocked by OPEN
    r2 = client.get("/proxy/ok")
    assert r2.status_code == 503


