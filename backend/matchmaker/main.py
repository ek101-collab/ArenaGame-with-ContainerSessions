from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uuid
import random
import string
import docker
import socket

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://46.101.127.20",
        "https://46.101.127.20.sslip.io"
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = docker.from_env()
active_sessions = {}

def get_free_port():
    for port in range(32000, 32101):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('', port))
                return port
            except OSError:
                continue
    return None

def generate_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))

@app.post("/create_session")
async def create_session():

    code = generate_code()
    while code in active_sessions:
        code = generate_code()

    assigned_port = get_free_port()
    if not assigned_port:
        raise HTTPException(status_code=500, detail="Keine freien Ports verfügbar")

    try:
        container = client.containers.run(
            "mein-game-server",
            detach=True, 
            ports={'8000/tcp': assigned_port}, 
            environment={"GAME_SESSION_CODE": code},
            auto_remove=True
        )
        public_domain = "46.101.127.20.sslip.io"
        tunnel_url = f"wss://{public_domain}/game/{assigned_port}/ws"
        
        active_sessions[code] = {"id": container.id, "url": tunnel_url}
        print(f"Session {code} gestartet. Tunnel: {tunnel_url}")
        
        return {"code": code, "url": tunnel_url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/join_session/{code}")
async def join_session(code: str):
    code = code.upper()
    if code in active_sessions:
        return {"url": active_sessions[code]["url"]}
    raise HTTPException(status_code=404, detail="Session nicht gefunden")


@app.post("/session_done/{code}")
async def session_done(code: str):
    code = code.upper()
    if code in active_sessions:
        del active_sessions[code]
        return {"status": "removed"}
    raise HTTPException(status_code=404, detail="Session nicht gefunden")