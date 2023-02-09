"""
Batch data ingest
"""
from datetime import datetime

from fastapi import APIRouter
from fastapi import BackgroundTasks
from fastapi import Depends
from fastapi import File
from fastapi import status
from fastapi import UploadFile
from webservices.api.v1.routes.route_login import get_current_user_from_token
from webservices.core.config import core_logger as logger
from webservices.schemas.files import IngestFileResponse
from webservices.schemas.users import UserSchema

router = APIRouter()


@router.post(
    "/upload",
    response_model=IngestFileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def ingest_file(
        background_tasks: BackgroundTasks,
        a_file: UploadFile = File(),
        a_user: UserSchema = Depends(get_current_user_from_token),
):
    """
    Batch file ingest route.

    UploadFile has the following parts:
    1. filename: A str with the original file name that was uploaded (e.g. myimage.jpg).
    2. content_type: A str with the content type (MIME type / media type)
        (e.g. image/jpeg).
    3. file: A SpooledTemporaryFile (a file-like object). This is the actual Python file
        that you can pass directly to other functions or libraries that expect a
        "file-like" object.

    """
    # Do cyber-tastic stuff with a_file
    logger.info(f"{a_file.filename} uploaded by {a_user.email}")
    return IngestFileResponse(
        timestamp=datetime.now(),
        filename=a_file.filename,
        user_email=a_user.email,
    )
