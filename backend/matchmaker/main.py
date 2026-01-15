from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import socket
import random
import string
import docker
import asyncio

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

def generate_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))

def is_port_open(ip, port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        try:
            s.connect((ip, int(port)))
            return True
        except (ConnectionRefusedError, socket.timeout, OSError):
            return False

@app.post("/create_session")
async def create_session():

    code = generate_code()
    while code in active_sessions:
        code = generate_code()

    try:
        container = client.containers.run(
            "mein-game-server",
            detach=True, 
            ports={'8000/tcp': ('127.0.0.1', None)},
            environment={"GAME_SESSION_CODE": code},
            auto_remove=True
        )
        assigned_port = None
        public_ip = "46.101.127.20"

        for _ in range(15):
            container.reload()
            if container.status == "running" and container.ports and '8000/tcp' in container.ports:
                assigned_port = container.ports['8000/tcp'][0]['HostPort']
                break
            await asyncio.sleep(0.2)

        if not assigned_port:
            container.stop()
            raise HTTPException(status_code=500, detail="Port-Mapping fehlgeschlagen")

        server_ready = False
        for _ in range(25):
            if is_port_open("localhost", assigned_port):
                server_ready = True
                break
            await asyncio.sleep(0.2)

        if not server_ready:
            container.stop()
            raise HTTPException(status_code=503, detail="Game-Server startet zu langsam")

        ip_address = f"{public_ip}:{assigned_port}"
        active_sessions[code] = {"id": container.id, "address": ip_address}
        
        return {"code": code, "ip": public_ip, "port": int(assigned_port)}

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