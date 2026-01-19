import logging
from typing import Dict, Tuple

import httpx
from fastapi import APIRouter, Request, Response

from src.config.settings import settings
from src.services.rate_limiter import RateLimiter
from src.services.circuit_breaker import CircuitBreaker, CircuitBreakerState


router = APIRouter()
logger = logging.getLogger("proxy")
rate_limiter = RateLimiter()
circuit_breaker = CircuitBreaker()


def _client_ip(request: Request) -> str:
    xff = request.headers.get("x-forwarded-for") or request.headers.get("X-Forwarded-For")
    if xff:
        return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _forward_headers(request: Request, ip: str) -> Dict[str, str]:
    headers = dict(request.headers)
    # Append X-Forwarded-For
    existing = headers.get("x-forwarded-for") or headers.get("X-Forwarded-For")
    if existing:
        headers["X-Forwarded-For"] = f"{existing}, {ip}"
    else:
        headers["X-Forwarded-For"] = ip
    return headers


async def _proxy_request(method: str, url: str, headers: Dict[str, str], content: bytes, query: str) -> Tuple[int, Dict[str, str], bytes]:
    full_url = url if not query else f"{url}?{query}"
    async with httpx.AsyncClient() as client:
        resp = await client.request(method, full_url, headers=headers, content=content)
        body = resp.content
        status = resp.status_code
        # Forward headers except transfer-encoding specifics
        resp_headers = {k: v for k, v in resp.headers.items()}
        return status, resp_headers, body


@router.api_route("/proxy/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
async def proxy(request: Request, path: str):
    ip = _client_ip(request)
    logger.info({
        "event": "incoming_request",
        "method": request.method,
        "path": path,
        "client_ip": ip,
    })

    allowed, retry_after = rate_limiter.allow(ip)
    if not allowed:
        logger.info({
            "event": "rate_limit_block",
            "client_ip": ip,
            "retry_after": retry_after,
        })
        return Response(
            content=b'{"error": "Too many requests, please try again later."}',
            status_code=429,
            media_type="application/json",
            headers={"Retry-After": str(retry_after)},
        )

    cb_allowed, state = circuit_breaker.before_request()
    if not cb_allowed and state == CircuitBreakerState.OPEN:
        logger.info({
            "event": "circuit_open_block",
            "state": state,
        })
        return Response(
            content=b'{"error": "Service temporarily unavailable due to circuit open."}',
            status_code=503,
            media_type="application/json",
        )

    # Build upstream URL
    upstream_base = str(settings.UPSTREAM_URL).rstrip("/")
    upstream_url = f"{upstream_base}/{path}"
    headers = _forward_headers(request, ip)
    body = await request.body()
    query = request.url.query

    try:
        status, resp_headers, resp_body = await _proxy_request(request.method, upstream_url, headers, body, query)
        # Success or failure?
        if status >= 500:
            circuit_breaker.record_failure()
        else:
            circuit_breaker.record_success()
        return Response(content=resp_body, status_code=status, headers=resp_headers)
    except Exception as e:
        logger.error({"event": "upstream_error", "error": str(e)})
        circuit_breaker.record_failure()
        return Response(
            content=b'{"error": "Upstream request failed."}',
            status_code=502,
            media_type="application/json",
        )
