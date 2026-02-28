import pytest
from fastapi.testclient import TestClient
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from matchmaker.main import app, MIN_PORT, MAX_PORT

client = TestClient(app)

def test_port_logic():
    """Prüft, ob die Port-Logik des Matchmakers im richtigen Bereich liegt."""
    from matchmaker.main import get_next_free_port
    port = get_next_free_port()
    assert MIN_PORT <= port <= MAX_PORT

def test_generate_code():
    """Prüft, ob der 4-stellige Session-Code korrekt generiert wird."""
    from matchmaker.main import generate_code
    code = generate_code()
    assert len(code) == 4
    assert code.isalnum()

def test_join_invalid_session():
    """Prüft, ob der Matchmaker einen 404 Fehler wirft, wenn eine Session nicht existiert."""
    response = client.get("/join_session/XXXX")
    assert response.status_code == 404