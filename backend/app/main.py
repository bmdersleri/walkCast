from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from backend.app.db.database import Base, engine
from backend.app.routes.items import router as items_router

app = FastAPI(title="walkCast API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

Base.metadata.create_all(bind=engine)

# Lightweight runtime migration for existing SQLite DBs.
with engine.begin() as conn:
    columns = conn.execute(text("PRAGMA table_info(items)")).fetchall()
    names = {col[1] for col in columns}
    if "file_size_bytes" not in names:
        conn.execute(text("ALTER TABLE items ADD COLUMN file_size_bytes INTEGER"))
    if "audio_quality" not in names:
        conn.execute(text("ALTER TABLE items ADD COLUMN audio_quality TEXT DEFAULT 'medium'"))
    if "playlist_name" not in names:
        conn.execute(text("ALTER TABLE items ADD COLUMN playlist_name TEXT"))

app.include_router(items_router)
app.mount("/backend/storage/audio", StaticFiles(directory="backend/storage/audio"), name="audio")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
