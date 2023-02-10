"""
File ingest Pydantic Schemas
"""
from datetime import datetime
from typing import List

from pydantic.networks import EmailStr
from webservices.schemas import BaseModel


class IngestFileResponse(BaseModel):
    """
    Response schema for route_ingest routes.
    """

    timestamp: datetime
    filename: str
    user_email: EmailStr


class IngestFileRequest(IngestFileResponse):
    """
    Expansion of the response to include the originating list of candump log strings
    """

    data: List[str]
