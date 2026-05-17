from fastapi import FastAPI

from backend.app.db.database import Base, engine
from backend.app.routes.items import router as items_router

app = FastAPI(title="walkCast API")

Base.metadata.create_all(bind=engine)

app.include_router(items_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
