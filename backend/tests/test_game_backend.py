import pytest
from fastapi.testclient import TestClient
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from game_backend.main import app

client = TestClient(app)

def test_game_websocket_connection():
    """Testet, ob ein Spieler eine WebSocket-Verbindung aufbauen kann."""
    with client.websocket_connect("/ws") as websocket:
        websocket.send_json({"type": "host", "name": "TestAdmin"})
        
        data = websocket.receive_json()
        assert data["type"] == "session_info"
        assert data["is_host"] is True
        assert "your_id" in data

def test_game_active_logic():
    """Prüft, ob das Spiel am Anfang als inaktiv markiert ist."""
    from game_backend.main import game_state
    assert game_state["is_active"] is False