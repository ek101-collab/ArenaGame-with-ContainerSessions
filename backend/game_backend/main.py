from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uuid
import random
import uvicorn
import asyncio
import os
import sys
import httpx

app = FastAPI()
SESSION_CODE = os.getenv("GAME_SESSION_CODE", "LOCAL")

game_state = {
    "players": {},
    "is_active": False,
    "host_id": None
}

async def notify_matchmaker_done():
    if SESSION_CODE != "LOCAL":
        url = f"http://46.101.127.20:8001/session_done/{SESSION_CODE}"
        try:
            async with httpx.AsyncClient() as client:
                await client.post(url)
        except Exception as e:
            print(f"Konnte Matchmaker nicht benachrichtigen: {e}")



async def shutdown_sequence():
    await asyncio.sleep(5)
    await notify_matchmaker_done() 
    print("Spiel beendet. Container fährt herunter...")
    os._exit(0)


@asynccontextmanager
async def lifespan(app: FastAPI):
    timeout_task = asyncio.create_task(idle_timeout_check()) 
    yield
    
    timeout_task.cancel()
app = FastAPI(lifespan=lifespan)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def broadcast(msg: dict):
    for p in game_state["players"].values():
        try:
            await p["ws"].send_json(msg)
        except: pass

async def broadcast_except_self(msg: dict, sender_id: str):
    for pid, pdata in game_state["players"].items():
        if pid != sender_id:
            try:
                await pdata["ws"].send_json(msg)
            except: pass

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    player_id = str(uuid.uuid4())
    
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            if msg_type in ["host", "join"]:
                name = data.get("name", "Anonym").strip()
                if not game_state["host_id"]:
                    game_state["host_id"] = player_id
                
                is_host = (game_state["host_id"] == player_id)
                
                if game_state["is_active"]:
                    await websocket.send_json({"type": "error", "message": "Spiel läuft bereits"})
                    continue

                game_state["players"][player_id] = {
                    "ws": websocket, 
                    "name": name, 
                    "is_alive": False,
                    "knockback": 0
                }

                await websocket.send_json({
                    "type": "session_info",
                    "code": SESSION_CODE,
                    "is_host": is_host,
                    "your_id": player_id,
                    "players": [{"id": pid, "name": p["name"]} for pid, p in game_state["players"].items()]
                })
                
                await broadcast({
                        "type": "player_list", 
                        "players": [{"id": pid, "name": p["name"]} for pid, p in game_state["players"].items()]
                    })

            elif msg_type == "start_game":
                if game_state["host_id"] == player_id:
                    game_state["is_active"] = True
                    player_data = []
                    for pid, pdata in game_state["players"].items():
                        game_state["players"][pid]["is_alive"] = True
                        player_data.append({"id": pid, "name": pdata["name"], "x": random.randint(0, 100), "y": random.randint(0, 100)})
                    
                    await broadcast({"type": "start_game", "players": player_data})

            elif msg_type == "player_state":
                data["id"] = player_id
                await broadcast_except_self(data, player_id)

            elif msg_type == "hit":
                target_id = data.get("target")
                if target_id in game_state["players"]:
                    
                    game_state["players"][target_id]["knockback"] += 10
                    new_val = game_state["players"][target_id]["knockback"]

                    await broadcast({
                        "type": "hit",
                        "from": data["from"],
                        "target": target_id,
                        "new_amount": new_val
                    })
                    
            elif msg_type == "player_died":
                p_data = game_state["players"].get(player_id)
                if p_data and p_data["is_alive"]:
                    p_data["is_alive"] = False
                    alive = [p for p in game_state["players"].values() if p["is_alive"]]
                    
                    if len(alive) == 1 and game_state["is_active"]:
                        await broadcast({"type": "game_over", "winner": alive[0]["name"]})
                        asyncio.create_task(shutdown_sequence())

    except WebSocketDisconnect:
        if player_id in game_state["players"]:
            del game_state["players"][player_id]

            if player_id == game_state["host_id"]:
                 await broadcast({"type": "error", "message": "Host hat das Spiel verlassen."})
                 asyncio.create_task(shutdown_sequence())
            else:
                await broadcast({
                    "type": "player_list", 
                    "players": [{"id": pid, "name": p["name"]} for pid, p in game_state["players"].items()]
                })

async def idle_timeout_check():
    try:
        await asyncio.sleep(300) 
        if not game_state["is_active"]:
            print("Timeout: Spiel wurde nicht gestartet. Fahre herunter...")
            await notify_matchmaker_done()
            os._exit(0)
    except asyncio.CancelledError:
        pass

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)