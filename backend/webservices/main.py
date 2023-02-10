"""
Primary FastAPI app instance instantiation and setup.
This will typically be called by __main__.py's implicit instantiation or directly by
Alembic and Pytest.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseSettings
from webservices.api import api_router_v1
from webservices.core.config import core_config


def get_application(a_config: BaseSettings = core_config) -> FastAPI:
    """
    Instantiate the FastAPI server instance
    :param a_config: A Pydantic BaseSettings object with relevant configuration settings
    :return: An instantiated FastAPI instance
    """

    _app = FastAPI(title=a_config.PROJECT_NAME, version=a_config.PROJECT_VERSION)
    _app.include_router(api_router_v1)

    # _app.add_event_handler("startup", some_task)

    _app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in a_config.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    return _app


app = get_application()
