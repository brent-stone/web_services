"""
Keycloak Pydantic schemas
"""
from typing import Dict
from typing import List

from pydantic import Field
from pydantic import validator
from webservices.schemas import BaseModel


def split_scopes_fn(a_str: str) -> List[str]:
    """
    Tokenize a scopes string into individual scopes
    :param a_str: A scopes string like "openid email profile"
    :return: A list equivalent like ['openid', 'email', 'profile']
    """
    try:
        return a_str.split(" ")
    except AttributeError:
        return []


class KeycloakTokenResponse(BaseModel):
    """
    Pydantic parser for response from keycloak library's token() callout
    """

    access_token: str
    expires_in: int
    refresh_expires_in: int
    refresh_token: str
    token_type: str = "Bearer"
    id_token: str
    not_before_policy: int = Field(alias="not-before-policy")
    session_state: str
    scope: List[str]

    _split_scopes = validator("scope", pre=True, allow_reuse=True)(split_scopes_fn)


class KeycloakTokenDecoded(BaseModel):
    """
    Pydantic schema for decoded keycloak authorization tokens
    """

    exp: int  # 1671390440
    iat: int  # 1671390140
    jti: str  # c6c84adc-8865-4d6e-b5fb-348d43ab28e9
    iss: str  # https://keycloak.localhost/realms/WebServices
    aud: str  # account
    sub: str  # e50a3-84d6-44d1-bfb3-419156de88c7
    typ: str  # Bearer
    azp: str  # webservices_api
    session_state: str  # 49aef4f2-6850-41cb-bb02-159eb300e980
    acr: int  # 1
    # ['http://localhost:57080/*', 'http://localhost:57444/*', 'http://localhost:57073/*']
    allowed_origins: List[str] = Field(alias="allowed-origins")
    # {'roles': ['offline_access', 'uma_authorization', 'default-roles-webservices']}
    realm_access: Dict[str, List[str]]
    # {'account': {'roles': ['manage-account', 'manage-account-links', 'view-profile']}}
    resource_access: Dict[str, Dict[str, List[str]]]
    scope: List[str]  # openid email profile
    sid: str  # 49aef4f2-6850-41cb-bb02-159eb300e980
    email_verified: bool
    name: str  # Brent Stone
    preferred_username: str  # brent@domain.com
    given_name: str  # Brent
    family_name: str  # Stone
    email: str  # Let's forgo the stricter Pydantic email field type

    _split_scopes = validator("scope", pre=True, allow_reuse=True)(split_scopes_fn)
