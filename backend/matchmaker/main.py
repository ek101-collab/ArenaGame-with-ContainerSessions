from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import random
import string
import docker

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://46.101.127.20.sslip.io",
        "https://matchmaker.46.101.127.20.sslip.io"
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = docker.from_env()

active_sessions = {}

def generate_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))

@app.post("/create_session")
async def create_session():
    code = generate_code()
    while code in active_sessions:
        code = generate_code()

    try:
        host = f"{code}.game.46.101.127.20.sslip.io"

        container = client.containers.run(
            "mein-game-server",
            detach=True,
            environment={"GAME_SESSION_CODE": code},
            labels={
                "caddy": host,
                "caddy.reverse_proxy": "{{upstreams 8000}}"
            },
            network="caddy_net",
            auto_remove=True
        )

        active_sessions[code] = {
            "id": container.id,
            "host": host
        }

        return {"code": code, "host": host}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/join_session/{code}")
async def join_session(code: str):
    code = code.upper()
    if code in active_sessions:
        return {"host": active_sessions[code]["host"]}
    raise HTTPException(status_code=404, detail="Session nicht gefunden")


@app.post("/session_done/{code}")
async def session_done(code: str):
    if code in active_sessions:
        del active_sessions[code]
        return {"status": "removed"}