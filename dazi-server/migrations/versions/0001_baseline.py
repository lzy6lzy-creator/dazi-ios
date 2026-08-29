"""Freeze the pre-Alembic production schema.

Revision ID: 0001_baseline
Revises:
Create Date: 2026-08-29
"""
from __future__ import annotations

from pathlib import Path
from typing import Sequence, Union

from alembic import op


revision: str = "0001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES_IN_CREATE_ORDER = (
    "beta_signups",
    "invitation_programs",
    "prompt_templates",
    "service_reminders",
    "site_feedback",
    "users",
    "agent_chat_messages",
    "agent_memories",
    "agents",
    "events",
    "location_verifications",
    "match_blocklists",
    "push_device_tokens",
    "user_invitation_accounts",
    "chat_rooms",
    "event_feedbacks",
    "event_gallery_items",
    "event_memories",
    "match_logs",
    "memory_evidence",
    "passive_match_requests",
    "signup_admissions",
    "chat_messages",
    "chat_room_members",
    "chat_room_votes",
    "invitation_ledger",
    "invitation_milestones",
)


def upgrade() -> None:
    sql_path = Path(__file__).resolve().parents[1] / "sql" / "0001_baseline.sql"
    for statement in sql_path.read_text(encoding="utf-8").split(";\n"):
        statement = statement.strip()
        if statement:
            op.get_bind().exec_driver_sql(statement)


def downgrade() -> None:
    for table_name in reversed(TABLES_IN_CREATE_ORDER):
        op.drop_table(table_name)
