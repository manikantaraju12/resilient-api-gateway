import sys
import os
sys.path.insert(0, "/app")

import fakeredis
import importlib


def test_rate_limiter_basic(monkeypatch):
    # Use fakeredis
    fake = fakeredis.FakeRedis(decode_responses=True)

    # Reload modules to ensure they use sys.path properly
    if "src.config.settings" in sys.modules:
        del sys.modules["src.config.settings"]
    if "src.services.redis_client" in sys.modules:
        del sys.modules["src.services.redis_client"]
    if "src.services.rate_limiter" in sys.modules:
        del sys.modules["src.services.rate_limiter"]

    from src.config.settings import settings

    # Configure small bucket
    settings.RATE_LIMIT_CAPACITY = 1
    settings.RATE_LIMIT_REFILL_RATE = 1.0

    # Patch Redis client factory
    monkeypatch.setattr("src.services.rate_limiter.get_redis_client", lambda: fake)
    
    # Reload to use patched version
    if "src.services.rate_limiter" in sys.modules:
        del sys.modules["src.services.rate_limiter"]
    
    from src.services.rate_limiter import RateLimiter

    rl = RateLimiter()
    allowed1, retry1 = rl.allow("1.2.3.4")
    assert allowed1 is True
    assert retry1 == 0

    allowed2, retry2 = rl.allow("1.2.3.4")
    assert allowed2 is False
    assert retry2 >= 1
