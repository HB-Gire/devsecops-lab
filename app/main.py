"""
devsecops-lab - API de ejemplo.

ATENCION: este archivo contiene vulnerabilidades INTENCIONALES (marcadas VULN-xx)
para que las herramientas del pipeline las detecten. El ejercicio es corregirlas
hasta que el pipeline de seguridad quede en verde. NO usar en produccion.
"""
import hashlib
import os
import sqlite3
import subprocess

import yaml
from flask import Flask, jsonify, request

app = Flask(__name__)

# VULN-01 (Secrets): credencial hardcodeada. Detecta: gitleaks / semgrep.
# Fix: leerla de una variable de entorno -> os.environ.get("PAYMENTS_API_KEY")
PAYMENTS_API_KEY = "sk_lab_9f8e7d6c5b4a39281706f5e4d3c2b1a0"

DB_PATH = os.environ.get("DB_PATH", "/tmp/lab.db")


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)")
    return conn


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/users")
def find_user():
    name = request.args.get("name", "")
    conn = get_db()
    # VULN-02 (SQL Injection): query armada con f-string. Detecta: bandit B608 / semgrep.
    # Fix: conn.execute("SELECT id, name FROM users WHERE name = ?", (name,))
    rows = conn.execute(f"SELECT id, name FROM users WHERE name = '{name}'").fetchall()
    return jsonify(users=[{"id": r[0], "name": r[1]} for r in rows])


@app.get("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # VULN-03 (Command Injection): shell=True con input del usuario. Detecta: bandit B602 / semgrep.
    # Fix: subprocess.run(["ping", "-c", "1", host], capture_output=True, text=True, check=False)
    out = subprocess.run(f"ping -c 1 {host}", shell=True, capture_output=True, text=True)
    return jsonify(output=out.stdout)


@app.post("/config")
def load_config():
    # VULN-04 (Deserializacion insegura): yaml.load sin SafeLoader. Detecta: bandit B506 / semgrep.
    # Fix: yaml.safe_load(request.data)
    data = yaml.load(request.data, Loader=yaml.Loader)
    return jsonify(loaded=bool(data))


@app.get("/hash")
def weak_hash():
    value = request.args.get("value", "")
    # VULN-05 (Criptografia debil): MD5. Detecta: bandit B324.
    # Fix: hashlib.sha256(value.encode()).hexdigest()
    return jsonify(hash=hashlib.md5(value.encode()).hexdigest())


if __name__ == "__main__":
    # VULN-06 (Config insegura): debug=True y bind a 0.0.0.0. Detecta: bandit B201/B104.
    # Fix: en contenedor usar gunicorn (ver Dockerfile) y nunca debug en prod.
    app.run(host="0.0.0.0", port=8080, debug=True)
