"""
Login routes and JWT logic
"""
from typing import Dict

from fastapi import APIRouter
from fastapi import Depends
from fastapi import HTTPException
from fastapi import Response
from fastapi import status
from fastapi.security import OAuth2PasswordRequestForm
from jose import JWTError
from pydantic import ValidationError
from webservices.api.utils import OAuth2PasswordBearerWithCookie
from webservices.core.config import core_config
from webservices.core.config import core_logger as logger
from webservices.core.config import keycloak_client
from webservices.schemas.keycloak import KeycloakTokenDecoded
from webservices.schemas.keycloak import KeycloakTokenResponse
from webservices.schemas.users import UserSchema

from keycloak import KeycloakAuthenticationError
from keycloak import KeycloakConnectionError

router = APIRouter()

login_route: str = "/v1/login/token"
# This tokenUrl is what Swagger will use for it's "Authenticate" button and appear in
# the routes as the login path.
oauth2_schema = OAuth2PasswordBearerWithCookie(tokenUrl=login_route)

credentials_exception = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid user credentials",
)


@router.post("/token")
def login_for_access_token(
    response: Response,
    form_data: OAuth2PasswordRequestForm = Depends(),
) -> Dict[str, str]:
    """
    Route for receiving a login/pass from the client and returning a JWT if the
    credentials correspond to an existing l_user.
    :param response: An HTTP response object
    :param form_data: The provided Oauth2 form data
    :return: An new access_token for the l_user
    """
    form_data.client_id = "webservices_api"
    form_data.client_secret = core_config.KEYCLOAK_CLIENT_SECRET_KEY
    form_data.grant_type = "oauth"
    logger.info(f"login attempt for: {form_data.username}")
    try:
        l_response: dict = keycloak_client.token(form_data.username, form_data.password)
        logger.info("Got keycloak response...")
        l_parsed_creds = KeycloakTokenResponse(**l_response)
        logger.info("Parsed keycloak response...")
    except KeycloakConnectionError:
        raise HTTPException(
            status_code=status.HTTP_424_FAILED_DEPENDENCY,
            detail="Failed to establish connection to authentication server",
        )
    except ValidationError:
        raise HTTPException(
            status_code=status.HTTP_424_FAILED_DEPENDENCY,
            detail="Failed to de-serialize authentication payload. Please contact the system admins.",
        )
    except KeycloakAuthenticationError:
        raise credentials_exception

    # This cookie is what will be expected to be provided by clients in the future when
    # attempting to access 'protected' routes.
    response.set_cookie(
        key="access_token", value=f"Bearer {l_parsed_creds.access_token}", httponly=True
    )

    l_return: Dict[str, str] = {
        "access_token": l_parsed_creds.access_token,
        "token_type": "bearer",
    }
    logger.info("Successful login")
    return l_return


def get_current_user_from_token(
    token: str = Depends(oauth2_schema),
) -> UserSchema:
    """
    Function to take a provided JWT and attempt to retrieve user information
    :param token: A JWT passed in from a REST endpoint
    :return: User information if valid; HTTP exception otherwise
    """
    if token is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Did not received an Authorization Bearer header with access token",
        )
    try:
        l_token = keycloak_client.decode_token(
            token,
            key=core_config.KEYCLOAK_PUBLIC_KEY,
            options=core_config.KEYCLOAK_DECRYPT_OPTIONS,
        )
        try:
            logger.info(f"Login for {l_token['email']}")
        except KeyError:
            logger.warn(f"Unexpected keycloak token format: {l_token}")
        l_token_parsed = KeycloakTokenDecoded(**l_token)
    except KeycloakConnectionError:
        raise HTTPException(
            status_code=status.HTTP_418_IM_A_TEAPOT,
            detail="Couldn't connect to keycloak",
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Access token invalid: {token}",
        )
    except ValidationError:
        raise HTTPException(
            status_code=status.HTTP_424_FAILED_DEPENDENCY,
            detail="Authentication succeeded but the server failed to parse decoded "
            "authentication token. Please contact the administrators.",
        )
    # Ensure valid tokens generate a User table entry if one doesn't already exist.
    try:
        return UserSchema(
            username=l_token_parsed.preferred_username,
            email=l_token_parsed.email,
        )
    except (HTTPException, ValidationError):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Invalid login.",
        )
