from sqlalchemy import text

from app.database.config import engine


def ensure_density_columns() -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                "ALTER TABLE density_data "
                "ADD COLUMN IF NOT EXISTS signal_strength DOUBLE PRECISION "
                "DEFAULT -95"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE density_data "
                "ADD COLUMN IF NOT EXISTS density_score INTEGER DEFAULT 0"
            )
        )
