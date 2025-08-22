from fastapi import Depends, FastAPI, Form, Request, status
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy import Boolean, Column, Integer, String, DateTime, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session, sessionmaker

# DB設定
from config import DATABASE_URL

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

templates = Jinja2Templates(directory="admin/templates")

# モデル
class AccessToken(Base):
    __tablename__ = "access_tokens"
    id = Column(Integer, primary_key=True, index=True)
    token = Column(String(128), unique=True, index=True, nullable=False)
    description = Column(String(256), default="")
    enabled = Column(Boolean, default=True)
    valid_from = Column(DateTime, nullable=True)
    valid_until = Column(DateTime, nullable=True)

Base.metadata.create_all(bind=engine)

app = FastAPI()
app.mount("/static", StaticFiles(directory="admin/static"), name="static")

# ローカルホストのみ許可
@app.middleware("http")
async def restrict_to_localhost(request: Request, call_next):
    client_host = request.client.host
    if client_host not in ("127.0.0.1", "::1", "localhost"):
        return RedirectResponse(url="/forbidden")
    return await call_next(request)

@app.get("/forbidden")
async def forbidden(request: Request):
    return templates.TemplateResponse("forbidden.html", {"request": request})

# トークン一覧
@app.get("/")
async def index(request: Request, db: Session = Depends(lambda: SessionLocal())):
    tokens = db.query(AccessToken).all()
    return templates.TemplateResponse("index.html", {"request": request, "tokens": tokens})

# トークン追加
@app.post("/add")
async def add_token(request: Request, token: str = Form(...), description: str = Form(""), valid_from: str = Form(None), valid_until: str = Form(None), db: Session = Depends(lambda: SessionLocal())):
    from datetime import datetime
    if not token:
        return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)
    valid_from_dt = None
    valid_until_dt = None
    dt_format = "%Y-%m-%dT%H:%M"  # HTML5 datetime-local形式
    try:
        if valid_from:
            valid_from_dt = datetime.strptime(valid_from, dt_format)
        if valid_until:
            valid_until_dt = datetime.strptime(valid_until, dt_format)
    except Exception:
        pass
    db.add(AccessToken(token=token, description=description, valid_from=valid_from_dt, valid_until=valid_until_dt))
    db.commit()
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

# トークン有効/無効切替
@app.post("/toggle/{token_id}")
async def toggle_token(token_id: int, db: Session = Depends(lambda: SessionLocal())):
    token = db.query(AccessToken).filter(AccessToken.id == token_id).first()
    if token:
        token.enabled = not token.enabled
        db.commit()
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

# トークン削除
@app.post("/delete/{token_id}")
async def delete_token(token_id: int, db: Session = Depends(lambda: SessionLocal())):
    token = db.query(AccessToken).filter(AccessToken.id == token_id).first()
    if token:
        db.delete(token)
        db.commit()
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)
