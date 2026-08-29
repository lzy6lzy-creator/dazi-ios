# Database migrations

`0001_baseline` is a frozen snapshot of the schema that existed before Alembic
was introduced. Existing installations must be stamped at that revision once;
new databases can run it normally.

Create every subsequent schema change as a new Alembic revision. Application
startup must never call `create_all()` or run ad-hoc `ALTER TABLE` statements.
