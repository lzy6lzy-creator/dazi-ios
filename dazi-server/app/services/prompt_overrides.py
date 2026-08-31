from sqlalchemy import select

from app.core.database import async_session
from app.models.prompt import PromptTemplate
from app.services.prompt_builder import PromptBuilder


async def load_prompt_overrides() -> None:
    """Replace process-local overrides with the current database snapshot."""
    async with async_session() as db:
        result = await db.execute(select(PromptTemplate))
        rows = result.scalars().all()
    PromptBuilder.reset_all_templates()
    for row in rows:
        if row.name in PromptBuilder._TEMPLATES:
            PromptBuilder.override_template(row.name, row.content)
