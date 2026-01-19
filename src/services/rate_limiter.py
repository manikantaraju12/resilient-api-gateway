import time
from typing import Tuple

from src.services.redis_client import get_redis_client
from src.config.settings import settings


RATE_LIMIT_KEY_PREFIX = "rate_limit:"


class RateLimiter:
    def __init__(self):
        self.redis = get_redis_client()
        self.capacity = settings.RATE_LIMIT_CAPACITY
        self.refill_rate = settings.RATE_LIMIT_REFILL_RATE

    def _key(self, client_ip: str) -> str:
        return RATE_LIMIT_KEY_PREFIX + client_ip

    def allow(self, client_ip: str) -> Tuple[bool, int]:
        key = self._key(client_ip)
        now = int(time.time())
        
        # Get current state
        data = self.redis.hgetall(key)
        if not data:
            # Initialize
            tokens = self.capacity
            last_refill = now
        else:
            tokens = float(data.get("tokens", self.capacity))
            last_refill = int(data.get("last_refill_time", now))
        
        # Refill
        elapsed = now - last_refill
        if elapsed > 0:
            tokens = min(self.capacity, tokens + elapsed * self.refill_rate)
            last_refill = now
        
        # Check and consume
        if tokens >= 1:
            tokens -= 1
            allowed = True
            retry_after = 0
        else:
            allowed = False
            retry_after = max(1, int((1 - tokens) / self.refill_rate)) if self.refill_rate > 0 else 1
        
        # Store updated state
        self.redis.hset(key, mapping={"tokens": tokens, "last_refill_time": last_refill})
        self.redis.expire(key, 3600)
        
        return allowed, retry_after

