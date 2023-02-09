"""
Keycloak client routes
"""
from fastapi import APIRouter
from fastapi import Depends
from fastapi import HTTPException
from fastapi import status
from jose.exceptions import JWTError
from webservices.api.v1.routes.route_login import get_current_user_from_token
from webservices.core.config import core_config
from webservices.core.config import keycloak_client

from keycloak import KeycloakConnectionError

router = APIRouter()


@router.post(
    "/auth_landing",
    status_code=status.HTTP_200_OK,
)
async def get_keycloak_auth_redirect(
    user_info=Depends(get_current_user_from_token),
) -> dict:
    """
    Return the Keycloak webapp adaptor config JSON. This config was retrieved from the
    Keycloak admin interface under the WebServices realm > webservices_webapp > Action > download
    adaptor configs

    Documentation about using this config with the Keycloak JavaScript adapter:
    https://www.keycloak.org/docs/latest/securing_apps/#_javascript_adapter

    :return: A keycloak adaptor config
    """
    return user_info


@router.post(
    "/test_token",
    status_code=status.HTTP_200_OK,
)
async def get_keycloak_config(access_token: str) -> dict:
    """
    Return the Keycloak webapp adaptor config JSON. This config was retrieved from the
    Keycloak admin interface under the WebServices realm > webservices_webapp > Action > download
    adaptor configs

    Documentation about using this config with the Keycloak JavaScript adapter:
    https://www.keycloak.org/docs/latest/securing_apps/#_javascript_adapter

    :return: A keycloak adaptor config
    """
    if access_token is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Did not received an Authorization bearer header",
        )
    try:
        return keycloak_client.decode_token(
            access_token,
            key=core_config.KEYCLOAK_PUBLIC_KEY,
            options=core_config.KEYCLOAK_DECRYPT_OPTIONS,
        )
    except KeycloakConnectionError:
        raise HTTPException(
            status_code=status.HTTP_418_IM_A_TEAPOT,
            detail="Couldn't connect to keycloak",
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token invalid",
        )


@router.post(
    "/test",
    status_code=status.HTTP_200_OK,
)
async def test_keycloak() -> dict:
    """
    Attempt to connect to keycloak and return info
    :return: A dictionary of info if successful; raise HTTPException otherwise.
    """
    try:
        return keycloak_client.well_known()
    except KeycloakConnectionError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"{e}")
