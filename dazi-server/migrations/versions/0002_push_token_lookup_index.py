"""Add the push-token lookup index and remove a legacy duplicate.

Revision ID: 0002_push_token_lookup_index
Revises: 0001_baseline
Create Date: 2026-08-29
"""
from typing import Sequence, Union

from alembic import op


revision: str = "0002_push_token_lookup_index"
down_revision: Union[str, None] = "0001_baseline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        "ix_push_device_tokens_user_active",
        "push_device_tokens",
        ["user_id", "is_active"],
        unique=False,
        if_not_exists=True,
    )
    op.execute("DROP INDEX IF EXISTS ix_push_device_tokens_token_unique")


def downgrade() -> None:
    op.drop_index(
        "ix_push_device_tokens_user_active",
        table_name="push_device_tokens",
        if_exists=True,
    )
