import logging
from typing import Dict, Optional

import httpx
from fastapi import Request

logger = logging.getLogger(__name__)


class ProxyService:
    def __init__(self, upstream_base_url: str, client: Optional[httpx.AsyncClient] = None) -> None:
        self.upstream_base_url = upstream_base_url.rstrip("/")
        self.client = client or httpx.AsyncClient()

    async def proxy(self, request: Request, path: str) -> httpx.Response:
        url = f"{self.upstream_base_url}/{path}"
        headers: Dict[str, str] = {k: v for k, v in request.headers.items()}

        client_ip = request.client.host if request.client else "unknown"
        xff = headers.get("x-forwarded-for")
        if xff:
            headers["x-forwarded-for"] = f"{client_ip}, {xff}"
        else:
            headers["x-forwarded-for"] = client_ip

        try:
            resp = await self.client.request(
                method=request.method,
                url=url,
                content=await request.body(),
                headers=headers,
                params=request.query_params,
                timeout=10.0,
            )
            logger.info(
                "proxy_forward",
                extra={"method": request.method, "path": path, "status": resp.status_code},
            )
            return resp
        except httpx.RequestError as exc:
            logger.error("upstream_unreachable", extra={"error": str(exc)})
            raise
