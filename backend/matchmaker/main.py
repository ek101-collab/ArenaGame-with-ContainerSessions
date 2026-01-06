from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uuid
import random
import string
import docker

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
        container = client.containers.run(
            "mein-game-server",
            detach=True, 
            ports={'8000/tcp': ('0.0.0.0', None)},
            environment={"GAME_SESSION_CODE": code},
            auto_remove=True
)
        container.reload()

        assigned_port = container.ports['8000/tcp'][0]['HostPort']
        ip_address = f"127.0.0.1:{assigned_port}"
        
        active_sessions[code] = {"id": container.id, "address": ip_address}
        print(f"Session {code} gestartet auf {ip_address}")
        
        return {"code": code, "ip": "DYNAMIC_HOST", "port": assigned_port}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/join_session/{code}")
async def join_session(code: str):
    code = code.upper()
    if code in active_sessions:
        addr = active_sessions[code]["address"].split(":")
        return {"ip": addr[0], "port": addr[1]}
    raise HTTPException(status_code=404, detail="Session nicht gefunden")


@app.post("/session_done/{code}")
async def session_done(code: str):
    if code in active_sessions:
        del active_sessions[code]
        return {"status": "removed"}