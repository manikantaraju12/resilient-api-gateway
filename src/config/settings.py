from pydantic import AnyHttpUrl
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PORT: int = 5000

    # Redis
    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379

    # Upstream
    UPSTREAM_URL: AnyHttpUrl = "http://upstream-service:5001"

    # Rate Limiting (Token Bucket)
    RATE_LIMIT_CAPACITY: int = 100
    RATE_LIMIT_REFILL_RATE: float = 10.0  # tokens per second

    # Circuit Breaker
    CIRCUIT_BREAKER_FAILURE_THRESHOLD: int = 5
    CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS: int = 30
    CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD: int = 2

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
