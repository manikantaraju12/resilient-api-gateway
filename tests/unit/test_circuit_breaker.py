import sys
sys.path.insert(0, "/app")

import fakeredis
import importlib


def test_circuit_breaker_transitions(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)

    # Reload modules
    for mod in ["src.config.settings", "src.services.redis_client", "src.services.circuit_breaker"]:
        if mod in sys.modules:
            del sys.modules[mod]

    from src.config.settings import settings
    
    # Configure thresholds
    settings.CIRCUIT_BREAKER_FAILURE_THRESHOLD = 2
    settings.CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS = 1
    settings.CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD = 1

    # Patch Redis client
    monkeypatch.setattr("src.services.circuit_breaker.get_redis_client", lambda: fake)
    
    # Reload circuit_breaker to use patched version
    if "src.services.circuit_breaker" in sys.modules:
        del sys.modules["src.services.circuit_breaker"]

    from src.services.circuit_breaker import CircuitBreaker, CircuitBreakerState
    import src.services.circuit_breaker as cb_module

    # Control time
    t = [1000]
    monkeypatch.setattr(cb_module.time, "time", lambda: t[0])

    cb = CircuitBreaker()

    # Initially CLOSED
    allowed, state = cb.before_request()
    assert allowed is True
    assert state == CircuitBreakerState.CLOSED

    # Fail twice -> OPEN
    cb.record_failure()
    cb.record_failure()
    allowed, state = cb.before_request()
    assert allowed is False
    assert state == CircuitBreakerState.OPEN

    # Advance time -> HALF_OPEN
    t[0] += settings.CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS + 1
    allowed, state = cb.before_request()
    assert allowed is True
    assert state == CircuitBreakerState.HALF_OPEN

    # Success -> CLOSED (threshold 1)
    cb.record_success()
    allowed, state = cb.before_request()
    assert allowed is True
    assert state == CircuitBreakerState.CLOSED
