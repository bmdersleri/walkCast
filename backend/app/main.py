from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from backend.app.db.database import Base, engine
from backend.app.routes.items import router as items_router

app = FastAPI(title="walkCast API")

Base.metadata.create_all(bind=engine)

app.include_router(items_router)
app.mount("/backend/storage/audio", StaticFiles(directory="backend/storage/audio"), name="audio")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
