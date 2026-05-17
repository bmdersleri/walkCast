from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.app.db.database import Base, engine
from backend.app.routes.items import router as items_router

app = FastAPI(title="walkCast API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5500",
        "http://localhost:5500",
        "http://127.0.0.1:8000",
        "http://localhost:8000",
        "null",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Base.metadata.create_all(bind=engine)

app.include_router(items_router)
app.mount("/backend/storage/audio", StaticFiles(directory="backend/storage/audio"), name="audio")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
