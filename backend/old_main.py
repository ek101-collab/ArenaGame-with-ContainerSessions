from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uuid
import random
import asyncio


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

sessions = {}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept(subprotocol=None)
    player_id = str(uuid.uuid4())
    session_code = None
    player_name = None

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            if msg_type == "host":
                name = data.get("name", "").strip()
                if not name:
                    await websocket.send_json({"type": "error", "message": "Name required"})
                    continue

                session_code = str(uuid.uuid4())[:4].upper()
                player_name = name

                sessions[session_code] = {
                    "host": websocket,
                    "is_active": False,
                    "players": {
                        player_id: {
                            "ws": websocket, 
                            "name": name, 
                            "is_alive": False
                        }
                    }
                }

                await websocket.send_json({
                    "type": "session_info",
                    "code": session_code,
                    "is_host": True,
                    "your_id": player_id,
                    "players": [name]
                })

                await broadcast_player_list(session_code)

            elif msg_type == "join":
                code = data.get("code", "").strip().upper()
                name = data.get("name", "").strip()
                if not name or not code:
                    await websocket.send_json({"type": "error", "message": "Code and Name required"})
                    continue

                if code not in sessions:
                    await websocket.send_json({"type": "error", "message": "Session not found"})
                    continue
            
                if sessions[code].get("is_active") == True:
                    await websocket.send_json({"type": "error", "message": "Spiel läuft bereits"})
                    continue

                session_code = code
                sessions[code]["players"][player_id] = {
                    "ws": websocket, 
                    "name": name, 
                    "is_alive": False
                }

                await websocket.send_json({
                    "type": "session_info",
                    "code": code,
                    "is_host": False,
                    "your_id": player_id,
                    "players": [p["name"] for p in sessions[code]["players"].values()]
                })

                await broadcast_player_list(code)

            elif msg_type == "start_game":
               if session_code and sessions[session_code]["host"] == websocket:
                    sessions[session_code]["is_active"] = True
                    player_data = []
                    for pid, pdata in sessions[session_code]["players"].items():
                        sessions[session_code]["players"][pid]["is_alive"] = True
                        player_data.append({
                            "id": pid, 
                            "name": pdata["name"], 
                            "x": random.randint(0, 100), 
                            "y": random.randint(0, 100)
                        })


                    await broadcast(session_code, {
                        "type": "start_game",
                        "players": player_data
                    })
            
            elif msg_type == "player_died":
                if session_code and session_code in sessions:
                    if player_id in sessions[session_code]["players"]:
                        sessions[session_code]["players"][player_id]["is_alive"] = False
                    
                    alive_players = [
                        pdata for pid, pdata in sessions[session_code]["players"].items() 
                        if pdata.get("is_alive", False)
                    ]

                    if len(alive_players) == 1:
                        sessions[session_code]["is_active"] = False
                        winner_name = alive_players[0]["name"]
                        await broadcast(session_code, {
                            "type": "game_over",
                            "winner": winner_name
                        })

                        async def cleanup_after_win(code_to_del):
                            await asyncio.sleep(1) 
                            if code_to_del in sessions:
                                del sessions[code_to_del]
                                print(f"Session {code_to_del} nach Sieg geschlossen.")
                        
                        asyncio.create_task(cleanup_after_win(session_code))
            
            if msg_type == "player_state":
                data["id"] = player_id 
                await broadcast_except_self(session_code, data, websocket)

            elif msg_type == "hit":
                target_id = data.get("target")
                if session_code in sessions and target_id in sessions[session_code]["players"]:

                    await broadcast(session_code, {
                        "type": "hit",
                        "from": data["from"],
                        "target": target_id
                    })

    except WebSocketDisconnect:
        if session_code and session_code in sessions:
            if player_id in sessions[session_code]["players"]:

                await broadcast_except_self(session_code, {
                    "type": "player_leave",
                    "player_id": player_id
                }, websocket)

                del sessions[session_code]["players"][player_id]

                if session_code in sessions:
                    alive_players = [p for p in sessions[session_code]["players"].values() if p.get("is_alive", False)]
                    if len(alive_players) == 1:
                        await broadcast(session_code, {"type": "game_over", "winner": alive_players[0]["name"]})


            if session_code in sessions:
                if sessions[session_code]["host"] == websocket:
                    await broadcast(session_code, {"type": "error", "message": "Host left, session closed"})
                    del sessions[session_code]
                    print(f"Session {session_code} durch Host-Abbruch gelöscht.")
                else:
                    await broadcast_player_list(session_code)


async def broadcast_player_list(session_code: str):
    players = [p["name"] for p in sessions[session_code]["players"].values()]
    msg = {"type": "player_list", "players": players}
    await broadcast(session_code, msg)

async def broadcast(session_code: str, msg: dict):
    for p in sessions[session_code]["players"].values():
        try:
            await p["ws"].send_json(msg)
        except:
            pass

async def broadcast_except_self(session_code: str, msg: dict, sender_ws: WebSocket):
    if session_code not in sessions:
        return
    for pid, pdata in sessions[session_code]["players"].items():
        if pdata["ws"] != sender_ws:
            try:
                await pdata["ws"].send_json(msg)
            except:
                pass

