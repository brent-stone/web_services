"""
FastAPI App primary global configuration which primarily relies upon .env file provided
values.
"""
import logging
from enum import Enum
from logging import captureWarnings
from logging import debug
from logging import error
from logging import getLogger
from logging import warning
from logging.config import dictConfig
from os import environ
from os import getenv
from time import sleep
from typing import Any
from typing import Dict
from typing import List
from typing import Optional
from typing import Union
from urllib.parse import quote_plus

from dotenv import find_dotenv
from dotenv import load_dotenv
from importlib_resources import as_file
from importlib_resources import files
from pydantic import AnyHttpUrl
from pydantic import BaseSettings
from pydantic import Field
from pydantic import PostgresDsn
from pydantic import RedisDsn
from pydantic import SecretStr
from pydantic import ValidationError
from pydantic import validator

from keycloak import KeycloakError
from keycloak import KeycloakOpenID


class LogLevel(str, Enum):
    """
    Explicit enumerated class for acceptable Uvicorn log levels.
    This type is primarily consumed by the core_logger setup.

    This datatype must be placed here instead of webservices.core.datatypes to prevent a
    circular import
    """

    CRITICAL = "CRITICAL"
    ERROR = "ERROR"
    WARNING = "WARNING"
    INFO = "INFO"
    DEBUG = "DEBUG"


if not getenv("REQUESTS_CA_BUNDLE"):
    """
    We may be running on a host machine so environment variables weren't sent via
    docker. Let's try to find a .env file and load its variables into the environment.
    """
    # first try to find a .test.env dev configuration then a production .env
    l_env_targets: List[str] = [".test.env", ".env"]
    l_env_target: str = ""

    for l_env_target in l_env_targets:
        # Iterate through all the backup .env file names
        l_env_path: str = find_dotenv(
            l_env_target, usecwd=True, raise_error_if_not_found=False
        )
        # If we received a non-empty string for the .env path, record the path
        # and proceed
        if bool(l_env_path):
            l_env_target = l_env_path
            warning(
                f"No environment variables appear to be set. Using values found in"
                f" {l_env_target}\n"
            )
            break

    # Only attempt to load a .env file if we successfully found one
    if bool(l_env_target):
        load_dotenv(dotenv_path=l_env_target, verbose=True, override=False)
        # If this is a test env file, assume we're on a localhost that will need to set
        # the REQUESTS_CA_BUNDLE environment variable so the self-signed key is trusted
        # by the Requests library's SSL layer
        if "test" in l_env_target:
            # Retrieve the absolute path to the public certificate
            with as_file(
                files("webservices.core.certs").joinpath("webservices.crt")
            ) as l_resource:
                environ["REQUESTS_CA_BUNDLE"] = str(l_resource)
                logging.info(
                    f"REQUESTS_CA_BUNDLE environment variable set to "
                    f"{getenv('REQUESTS_CA_BUNDLE')}"
                )


class CoreConfig(BaseSettings):
    """
    Primary Pydantic parser for environment variables used throughout the API layer.
    """

    DEBUG: bool = Field(..., env="DEBUG")
    LOG_LEVEL: LogLevel = Field(..., env="LOG_LEVEL")

    PROJECT_NAME: str = Field(..., env="PROJECT_NAME")
    PROJECT_VERSION: str = Field(..., env="PROJECT_VERSION")

    DEFAULT_USERNAME: str = Field(..., env="DEFAULT_USERNAME")
    DEFAULT_USER_PASS: str = Field(..., env="DEFAULT_USER_PASS")
    DEFAULT_EMAIL: str = Field(..., env="DEFAULT_EMAIL")

    SECRET_KEY: str = Field(..., env="SECRET_KEY")
    HASH_ALGORITHM: str = Field(..., env="HASH_ALGORITHM")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        ..., env="ACCESS_TOKEN_EXPIRE_MINUTES", gt=0
    )
    BACKEND_CORS_ORIGINS: List[AnyHttpUrl] = []

    KC_HTTPS_PORT: str = Field(..., env="KC_HTTPS_PORT")
    KEYCLOAK_HOSTNAME: str = Field(..., env="KEYCLOAK_HOSTNAME")
    KEYCLOAK_URL: Optional[str] = None
    KEYCLOAK_CLIENT_SECRET_KEY: str = Field(..., env="KEYCLOAK_CLIENT_SECRET_KEY")
    KEYCLOAK_PUBLIC_KEY: Optional[str] = None
    KEYCLOAK_DECRYPT_OPTIONS: Dict[str, bool] = {
        "verify_signature": True,
        "verify_aud": False,
        "verify_exp": True,
    }
    KEYCLOAK_LOGIN_WAIT_SEC: int = Field(..., env="KEYCLOAK_LOGIN_WAIT_SEC")
    KEYCLOAK_LOGIN_RETRY_COUNT: int = Field(..., env="KEYCLOAK_LOGIN_RETRY_COUNT")

    # Note: Pydantic's BaseSettings class will automatically pull in environmental
    # values when setting the 'env' flag in Field
    POSTGRES_SERVER: str = Field(..., env="POSTGRES_SERVER")
    POSTGRES_USER: str = Field(..., env="POSTGRES_USER")
    # Note: Pydantic SecretStr requires an explicit call to the .get_secret_value()
    # function to get a cleartext value
    # An example of this in action is the generate_db_uri() function below.
    POSTGRES_PASSWORD: SecretStr = Field(..., env="POSTGRES_PASSWORD")
    POSTGRES_DB: str = Field(..., env="POSTGRES_DB")
    POSTGRES_PORT: str = Field(..., env="POSTGRES_PORT")
    DATABASE_URI: Optional[PostgresDsn] = None
    DATABASE_URI_GENERIC: Optional[PostgresDsn] = None
    DATABASE_URI_HIDDEN_PASS: Optional[str] = None

    CELERY_BROKER_URL: RedisDsn = Field(..., env="CELERY_BROKER_URL")
    CELERY_RESULT_BACKEND: RedisDsn = Field(..., env="CELERY_RESULT_BACKEND")
    celery_concurrency_count: int = 0
    celery_worker_count: int = 0

    @validator("KEYCLOAK_URL")
    def generate_keycloak_url(cls, v: Optional[str], values: Dict[str, Any]) -> str:
        """
        Dynamically generate the Keycloak internal HTTPS URL
        :param v: Unused
        :param values: Dictionary of current BaseSettings attributes
        :return: The formatted URL
        """
        return (
            f"https://{values.get('KEYCLOAK_HOSTNAME')}:{values.get('KC_HTTPS_PORT')}"
            # f"https://{values.get('KEYCLOAK_HOSTNAME')}"
        )

    @validator("LOG_LEVEL", pre=True)
    def uppercase_log_level(cls, v: Any) -> LogLevel:
        """
        Ensure provided LOG_LEVEL values are converted to all uppercase then LogLevel
        @param v: The provided LOG_LEVEL value
        @type v: Any
        @return: Initialized LogLevel enum; "WARNING" upon error
        @rtype: LogLevel
        """
        if isinstance(v, str):
            try:
                return LogLevel(v.upper())
            except ValueError:
                pass
        logging.warning(f"Invalid log level: {v}. Setting LOG_LEVEL to WARNING.")
        return LogLevel.WARNING

    @validator("BACKEND_CORS_ORIGINS", pre=True)
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
        """
        Pre-parse the string of acceptable CORS origins from environment variable
        :param v: The raw string passed in from the environment variable
        :return: A list of substrings, one entry per URL or IP substring
        """
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

    # NOTE: This method for ensuring *_text database names when is left as a reference.
    # However, Brent recommends the more cognitively simple and predictable strategy of
    # relying on a manually named *_test POSTGRES_DB value in .test.env in the /backend
    # or .env in the top-level environment variable file.

    # Pydantic field ordering rules should ensure that POSTGRES_DB is updated prior to
    # DATABASE_URI. Thus, we can append testing_postfix to POSTGRES_DB here and all
    # areas that would use the modified string, such as Alembic's env.py, automatically
    # get the correct database name.
    # https://pydantic-docs.helpmanual.io/usage/models/#field-ordering
    # @validator("POSTGRES_DB")
    # def append_db_name_if_testing(cls, v: Optional[str], values: Dict[str, Any]) -> str:
    #     if not isinstance(v, str):
    #         logger.error(
    #             "Failed to get a valid POSTGRES_DB value from environment or .env"
    #         )
    #         raise ValueError
    #     # Append the testing postfix string to the database name if we're in DEBUG mode.
    #     if values.get("DEBUG") is True:
    #         v += testing_postfix_str
    #         logger.info(f"POSTGRES_DB updated for testing to: {v}")
    #     return v

    # Note from Brent: Accessing CLASS (not object) variables is super awkward in Python
    # and prone to difficult bugs. I got this template code from the fastapi
    # auto-template project linked below, but I honestly have no idea how the 'values'
    # dict is making it into this function.
    # https://github.com/ycd/manage-fastapi
    @validator("DATABASE_URI")
    def generate_db_uri(cls, v: Optional[str], values: Dict[str, Any]) -> Any:
        """
        Populate the primary postgres database URI for the API to find the service.

        NOTE: Docker Compose's service alias' like "db" will include any changes to
        the service's port. Thus, if we specify port here then the connection will
        be refused because SQLAlchemy will be looking for a connection like
        0.0.0.0:57074:57074  Simply let compose handle changes to the port via the
        alias stored in POSTGRES_SERVER.

        Rely upon the DEBUG environment variable to differentiate when and when not
        to include the POSTGRES_PORT in the PostgresDsn creation.
        If True (we expect to be working outside the container like localhost) then
        include POSTGRES PORT.
        If False, don't include POSTGRES_PORT and rely on Docker Compose aliasing
        """
        # Boilerplate which shouldn't be triggered. Warn if it is.
        if isinstance(v, str):
            warning(f"Database URI provided instead of auto-generated: {v}")
            return v

        if str(values.get("DEBUG")).lower() == "true":
            debug("Using Postgres URI that doesn't include port [likely for localhost]")
            # Include POSTGRES_PORT
            return PostgresDsn.build(
                scheme="postgresql",
                # It's necessary to escape special characters in order for Pydantic,
                # Alembic, and inter-container comms to Postgres to behave well
                user=quote_plus(values.get("POSTGRES_USER")),
                password=quote_plus(values.get("POSTGRES_PASSWORD").get_secret_value()),
                host=quote_plus(values.get("POSTGRES_SERVER")),
                port=quote_plus(values.get("POSTGRES_PORT")),
                path=f"/{quote_plus(values.get('POSTGRES_DB'))}",
            )
        else:
            debug("Using Postgres URI that does include port")
            # Don't include the POSTGRES_PORT
            return PostgresDsn.build(
                scheme="postgresql",
                user=quote_plus(values.get("POSTGRES_USER")),
                password=quote_plus(values.get("POSTGRES_PASSWORD").get_secret_value()),
                host=quote_plus(values.get("POSTGRES_SERVER")),
                # port=quote_plus(values.get("POSTGRES_PORT")),
                path=f"/{quote_plus(values.get('POSTGRES_DB'))}",
            )

    @validator("DATABASE_URI_HIDDEN_PASS")
    def generate_db_dsn(cls, v: Optional[str], values: Dict[str, Any]) -> Any:
        """
        Populate the reference database DSN for logging purposes.
        """
        try:
            return PostgresDsn.build(
                scheme="postgresql",
                user=quote_plus(values.get("POSTGRES_USER")),
                password=str(values.get("POSTGRES_PASSWORD")),
                host=quote_plus(values.get("POSTGRES_SERVER")),
                port=quote_plus(values.get("POSTGRES_PORT")),
                path=f"/{quote_plus(values.get('POSTGRES_DB'))}",
            )
        except ValidationError:
            debug("Failed to create DATABASE_URI_HIDDEN_PASS")
            return None

    @validator("DATABASE_URI_GENERIC")
    def generate_db_uri_generic(cls, v: Optional[str], values: Dict[str, Any]) -> Any:
        """It's possible (likely even) that the test database doesn't exist yet.
        However, our default DATABASE_URI will return a string with pinpoint info
        to try to connect to a particular database. The result is Alembic, pytest,
        etc. will potentially crash trying to connect directly to a non-existent
        database.

        Thus, we're going to use DATABASE_URI less the POSTGRES_DB portion to open
        a generic connection to Postgres.

        This is primarily used in alembic's env.py run_migrations_online() script.

        Example:
        Original: postgresql://webservices:pass@localhost/webservices_test
        Rsplit: ['postgresql://webservices:pass@localhost', 'webservices_test']
        Return value: postgresql://webservices:pass@localhost

        Args:
            v (Optional[str]): The auto-generated DATABASE_URI
            values (Dict[str, Any]): Dict of currently processed environment variables

        Returns:
            Any: A database URI less the trailing '/table_name'
        """
        # Right split on the 1st rightmost '/' character, then return leading token.
        try:
            l_uri = PostgresDsn.build(
                scheme="postgresql",
                user=quote_plus(values.get("POSTGRES_USER")),
                password=quote_plus(values.get("POSTGRES_PASSWORD").get_secret_value()),
                host=quote_plus(values.get("POSTGRES_SERVER")),
                port=quote_plus(values.get("POSTGRES_PORT")),
                path=f"/{quote_plus(values.get('POSTGRES_DB'))}",
            )
            return l_uri.rsplit("/", 1)[0]
        except (ValueError, IndexError, AttributeError) as e:
            error(
                f"Failed to generate generic database URI less the specific \
                database target: {e}"
            )
            return values.get("DATABASE_URI")

    class Config:
        """
        Customize the default BaseSettings class behavior
        """

        case_sensitive = True
        # env_file = ".env"


core_config = CoreConfig()


LOG_CONFIG = {
    "version": 1,
    # "disable_existing_loggers": True,
    "formatters": {
        "default": {
            "format": "%(levelname)s:\t [%(filename)s:%(funcName)s:%(lineno)d]:\t %(message)s"
        }
    },
    "handlers": {
        "console": {
            "formatter": "default",
            "class": "logging.StreamHandler",
            "stream": "ext://sys.stdout",
            "level": core_config.LOG_LEVEL.value,
        }
    },
    "root": {"handlers": ["console"], "level": core_config.LOG_LEVEL.value},
    "loggers": {
        "gunicorn": {"propagate": True},
        "gunicorn.access": {"propagate": True},
        "gunicorn.error": {"propagate": True},
        "uvicorn": {"propagate": True},
        "uvicorn.access": {"propagate": True},
        "uvicorn.error": {"propagate": True},
        # https://docs.celeryq.dev/en/stable/userguide/tasks.html#logging
        "celery": {"propagate": True},
        "celery.task": {"propagate": True},
        "celery.app.trace": {"propagate": True},
    },
}

captureWarnings(True)
dictConfig(LOG_CONFIG)
core_logger = getLogger(__name__)
core_logger.info(f"Database URI being used: {core_config.DATABASE_URI_HIDDEN_PASS}")
# core_logger.debug(str(core_config))

# Configure keycloak client
# NOTE: The `verify=` field can be set to False or a path to the public certificate file
# if there are issues with the SSL layer.
keycloak_client = KeycloakOpenID(
    server_url=core_config.KEYCLOAK_URL,
    realm_name="WebServices",
    client_id="webservices_api",
    client_secret_key=core_config.KEYCLOAK_CLIENT_SECRET_KEY,
    verify=True,
)

# Ensure we have a working connection to keycloak
for i in range(core_config.KEYCLOAK_LOGIN_RETRY_COUNT):
    try:
        # An alternative could be reading from the local copy of the certificate.
        # This callout provides a convenient check to ensure the connection to keycloak
        # is working.
        core_config.KEYCLOAK_PUBLIC_KEY = (
            "-----BEGIN PUBLIC KEY-----\n"
            + keycloak_client.public_key()
            + "\n-----END PUBLIC KEY-----"
        )
        core_logger.info("Successfully connected to keycloak.")
        break
    except KeycloakError as e:
        core_logger.warning(
            f"Failed to connect to keycloak at {core_config.KEYCLOAK_URL}"
        )
        core_logger.warning(f"{e}")
        core_logger.warning(
            f"\t{core_config.KEYCLOAK_LOGIN_RETRY_COUNT-i} retries pending..."
        )
        sleep(core_config.KEYCLOAK_LOGIN_WAIT_SEC)
if core_config.KEYCLOAK_PUBLIC_KEY is None:
    core_logger.error("Failed to connect to keycloak. Exiting...")
    exit(-1)
