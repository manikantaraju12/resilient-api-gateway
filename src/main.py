import logging
from fastapi import FastAPI
from src.routes.health_routes import router as health_router
from src.routes.proxy_routes import router as proxy_router


def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


def create_app() -> FastAPI:
    setup_logging()
    app = FastAPI(title="Resilient API Gateway")
    app.include_router(health_router)
    app.include_router(proxy_router)
    return app


app = create_app()
