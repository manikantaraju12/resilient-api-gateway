import time
import logging
from typing import Tuple

from src.services.redis_client import get_redis_client
from src.config.settings import settings


logger = logging.getLogger("circuit_breaker")

CB_KEY = "circuit_breaker:upstream_service"


class CircuitBreakerState:
    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF_OPEN"


class CircuitBreaker:
    def __init__(self):
        self.redis = get_redis_client()
        self.failure_threshold = settings.CIRCUIT_BREAKER_FAILURE_THRESHOLD
        self.reset_timeout = settings.CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS
        self.half_open_success_threshold = settings.CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD

    def _get_state_data(self) -> dict:
        data = self.redis.hgetall(CB_KEY)
        if not data:
            now = int(time.time())
            self.redis.hset(CB_KEY, mapping={
                "state": CircuitBreakerState.CLOSED,
                "failure_count": 0,
                "success_count": 0,
                "last_state_change_time": now,
            })
            data = {
                "state": CircuitBreakerState.CLOSED,
                "failure_count": "0",
                "success_count": "0",
                "last_state_change_time": str(now),
            }
        return data

    def _set_state(self, state: str):
        now = int(time.time())
        logger.info({
            "event": "cb_state_change",
            "new_state": state,
            "timestamp": now,
        })
        self.redis.hset(CB_KEY, mapping={
            "state": state,
            "last_state_change_time": now,
            "failure_count": 0,
            "success_count": 0,
        })

    def before_request(self) -> Tuple[bool, str]:
        data = self._get_state_data()
        state = data.get("state", CircuitBreakerState.CLOSED)
        last_change = int(data.get("last_state_change_time", 0))
        now = int(time.time())

        if state == CircuitBreakerState.OPEN:
            if now - last_change >= self.reset_timeout:
                # Move to HALF_OPEN, allow a probe
                self._set_state(CircuitBreakerState.HALF_OPEN)
                return True, CircuitBreakerState.HALF_OPEN
            else:
                return False, CircuitBreakerState.OPEN

        # CLOSED or HALF_OPEN: allow
        return True, state

    def record_success(self):
        data = self._get_state_data()
        state = data.get("state", CircuitBreakerState.CLOSED)
        if state == CircuitBreakerState.CLOSED:
            # Reset failures on success
            self.redis.hset(CB_KEY, "failure_count", 0)
            return

        if state == CircuitBreakerState.HALF_OPEN:
            success_count = int(data.get("success_count", 0)) + 1
            if success_count >= self.half_open_success_threshold:
                self._set_state(CircuitBreakerState.CLOSED)
            else:
                self.redis.hset(CB_KEY, "success_count", success_count)

    def record_failure(self):
        data = self._get_state_data()
        state = data.get("state", CircuitBreakerState.CLOSED)
        if state == CircuitBreakerState.CLOSED:
            failure_count = int(data.get("failure_count", 0)) + 1
            if failure_count >= self.failure_threshold:
                self._set_state(CircuitBreakerState.OPEN)
            else:
                self.redis.hset(CB_KEY, "failure_count", failure_count)
            return

        if state == CircuitBreakerState.HALF_OPEN:
            # Any failure in HALF_OPEN triggers OPEN
            self._set_state(CircuitBreakerState.OPEN)
