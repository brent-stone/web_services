"""
Cumulative routes from all API versions
"""
from fastapi import APIRouter
from webservices.api.v1.routes import route_keycloak
from webservices.api.v1.routes import route_login
from webservices.api.v1.routes import route_upload


api_router_v1 = APIRouter(prefix="/v1")

# WebServices v1 REST Endpoints
api_router_v1.include_router(route_login.router, prefix="/login", tags=["Login"])
api_router_v1.include_router(route_upload.router, prefix="/upload", tags=["Upload"])
api_router_v1.include_router(route_keycloak.router, prefix="/keycloak", tags=["Keycloak"])
