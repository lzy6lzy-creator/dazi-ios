"""Reconcile pre-Alembic installations with the frozen schema contract.

Revision ID: 0003_reconcile_legacy_schema
Revises: 0002_push_token_lookup_index
Create Date: 2026-08-29
"""
from typing import Sequence, Union

from alembic import op


revision: str = "0003_reconcile_legacy_schema"
down_revision: Union[str, None] = "0002_push_token_lookup_index"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE agent_memories SET scope = 'long_term' WHERE scope IS NULL")
    op.execute("UPDATE agent_memories SET occurrence_count = 1 WHERE occurrence_count IS NULL")
    op.execute("UPDATE agent_memories SET status = 'active' WHERE status IS NULL")
    op.execute("UPDATE chat_messages SET visibility = 'public_room' WHERE visibility IS NULL")
    op.execute("UPDATE chat_room_votes SET created_at = NOW() WHERE created_at IS NULL")
    op.execute("UPDATE chat_rooms SET match_type = 'active' WHERE match_type IS NULL")
    op.execute("UPDATE chat_rooms SET phase = 'matched' WHERE phase IS NULL")
    op.execute("UPDATE users SET avatar_emoji = '😊' WHERE avatar_emoji IS NULL")
    op.execute("UPDATE users SET welcome_disturb = FALSE WHERE welcome_disturb IS NULL")
    op.execute(
        "UPDATE users SET profile_event_visibility = 'partial' "
        "WHERE profile_event_visibility IS NULL"
    )

    for table_name, column_name in (
        ("agent_memories", "scope"),
        ("agent_memories", "occurrence_count"),
        ("agent_memories", "status"),
        ("chat_messages", "visibility"),
        ("chat_room_votes", "created_at"),
        ("chat_rooms", "match_type"),
        ("chat_rooms", "phase"),
        ("users", "avatar_emoji"),
        ("users", "welcome_disturb"),
        ("users", "profile_event_visibility"),
    ):
        op.execute(
            f'ALTER TABLE "{table_name}" ALTER COLUMN "{column_name}" SET NOT NULL'
        )

    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_agent_memories_key "
        "ON agent_memories (key)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_chat_messages_recipient_user_id "
        "ON chat_messages (recipient_user_id)"
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'chat_room_votes'::regclass
                  AND conname = 'chat_room_votes_room_id_user_id_key'
            ) AND NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'chat_room_votes'::regclass
                  AND conname = 'uq_chat_room_votes_room_user'
            ) THEN
                ALTER TABLE chat_room_votes
                RENAME CONSTRAINT chat_room_votes_room_id_user_id_key
                TO uq_chat_room_votes_room_user;
            END IF;
        END $$
        """
    )


def downgrade() -> None:
    # This migration only makes legacy stamped databases match 0001_baseline.
    # Fresh databases already have these constraints, so there is nothing safe
    # or useful to undo here.
    pass
