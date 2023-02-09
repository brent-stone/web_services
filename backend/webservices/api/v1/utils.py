from typing import Dict
from typing import Optional

from fastapi import HTTPException
from fastapi import Request
from fastapi import status
from fastapi.openapi.models import OAuthFlows as OAuthFlowsModel
from fastapi.security import OAuth2
from fastapi.security.utils import get_authorization_scheme_param
from webservices.core.config import core_logger as logger


class OAuth2PasswordBearerWithCookie(OAuth2):
    """
    JSON Web Token based authentication class
    """

    def __init__(
        self,
        tokenUrl: str,
        scheme_name: Optional[str] = None,
        scopes: Optional[Dict[str, str]] = None,
        auto_error: bool = True,
    ):
        if not scopes:
            scopes = {}
        flows = OAuthFlowsModel(password={"tokenUrl": tokenUrl, "scopes": scopes})
        super().__init__(flows=flows, scheme_name=scheme_name, auto_error=auto_error)

    async def __call__(self, request: Request) -> Optional[str]:
        # Alternative cookie based header retrieval
        # authorization: str = request.cookies.get(
        #     "access_token"
        # )  # changed to accept access token from httpOnly Cookie
        authorization: str = request.headers.get("Authorization")

        scheme, param = get_authorization_scheme_param(authorization)
        if not authorization or scheme.lower() != "bearer":
            if self.auto_error:
                logger.debug(
                    f"Rejecting login.\n"
                    f"Authorization: {authorization}\n"
                    f"Scheme: {scheme}\n"
                    f"Param: {param}"
                )
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="access_token cookie not provided or invalid. "
                    "Please login again to refresh your credentials.",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            else:
                return None
        return param
