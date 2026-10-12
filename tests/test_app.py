import pytest

from app.main import app


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr("app.main.DB_PATH", str(tmp_path / "test.db"))
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json() == {"status": "ok"}


def test_users_empty(client):
    r = client.get("/users?name=nadie")
    assert r.status_code == 200
    assert r.get_json() == {"users": []}


def test_hash_returns_hex(client):
    r = client.get("/hash?value=abc")
    assert r.status_code == 200
    assert all(c in "0123456789abcdef" for c in r.get_json()["hash"])


# Test de seguridad: una inyeccion no debe devolver filas.
# Esta marcado xfail mientras VULN-02 exista; al corregirla, quitar el decorador.
@pytest.mark.xfail(reason="VULN-02 sin corregir", strict=False)
def test_users_sqli_does_not_leak(client):
    from app.main import get_db

    conn = get_db()
    conn.execute("INSERT INTO users (name) VALUES ('alice')")
    conn.commit()
    r = client.get("/users?name=' OR '1'='1")
    assert r.status_code == 200
    # Con la VULN-02 sin corregir, esto devuelve a 'alice' y el test falla.
    assert r.get_json()["users"] == [], "SQL injection: corregir VULN-02"
