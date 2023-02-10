"""
User Pydantic Schemas
"""
from pydantic import EmailStr
from pydantic import validator
from webservices.core.hashing import Hasher
from webservices.schemas import BaseModel
from webservices.schemas import render_safe_email
from webservices.schemas import username_str


class UserLoginSchema(BaseModel):
    """
    Facilitate user authentication
    """

    username: username_str
    password: str

    _hash_pass = validator("password", allow_reuse=True)(Hasher.get_password_hash)


class UserCreateUpdateSchema(UserLoginSchema):
    """
    Extension of UserLoginSchema to include email
    """

    # username inherited from UserLoginSchema
    # password inherited from UserLoginSchema
    email: EmailStr

    _sanitize_email = validator("email", allow_reuse=True)(render_safe_email)


class UserAdminCreateUpdateSchema(UserCreateUpdateSchema):
    """
    Extension of UserCreateUpdateSchema schema to allow modification of features which
    should only be made by admins.

    """

    # username inherited from UserCreateUpdateSchema
    # password inherited from UserCreateUpdateSchema
    # email inherited from UserCreateUpdateSchema
    is_active: bool = True
    is_superuser: bool = False


class UserSchema(BaseModel):
    """
    Generic User schema for conveying details about users less sensitive info
    """

    id: int = 1
    username: username_str
    email: EmailStr
    is_active: bool = True
    is_superuser: bool = False

    _sanitize_email = validator("email", allow_reuse=True)(render_safe_email)
