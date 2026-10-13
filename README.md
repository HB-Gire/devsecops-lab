# devsecops-lab

Laboratorio basico de DevSecOps: una API Flask **con vulnerabilidades intencionales** + un pipeline
de GitHub Actions que las detecta. El objetivo es ver cada herramienta en accion, entender que
encuentra y practicar el ciclo **detectar -> corregir -> pipeline en verde**.

> No desplegar esta app en ningun entorno real.

## Que hay en el repo

| Archivo | Para que sirve |
|---|---|
| `app/main.py` | API con 6 vulnerabilidades marcadas `VULN-01..06` |
| `requirements.txt` | Dependencias viejas con CVEs (`VULN-07`) |
| `tests/` | Tests unitarios + un test de seguridad (SQLi) en `xfail` |
| `Dockerfile` | Plantilla con buenas practicas (multi-stage, no-root, healthcheck) |
| `.pre-commit-config.yaml` | Controles locales antes de cada commit (gitleaks, ruff, bandit, hadolint) |
| `.semgrep/rules.yml` | Reglas SAST propias ("policy as code") |
| `.github/workflows/ci.yml` | Lint + tests + build + Trivy imagen + SBOM |
| `.github/workflows/security.yml` | Secrets + SAST + SCA + IaC (push, PR y semanal) |
| `.github/workflows/dast.yml` | OWASP ZAP baseline contra la app levantada (manual/semanal) |
| `.github/dependabot.yml` | PRs automaticos de actualizacion (pip, actions, docker) |
| `Makefile` | Los mismos chequeos para correr local (`make help`) |
| `soluciones/fixes.diff` | Las correcciones (mirar despues de intentarlo) |

## Mapa de vulnerabilidades -> herramienta

| ID | Tipo | OWASP | La detecta |
|---|---|---|---|
| VULN-01 | Secreto hardcodeado | A07 | gitleaks, semgrep |
| VULN-02 | SQL Injection | A03 | bandit B608, semgrep, test xfail |
| VULN-03 | Command Injection | A03 | bandit B602, semgrep |
| VULN-04 | Deserializacion YAML | A08 | bandit B506, semgrep |
| VULN-05 | Hash debil (MD5) | A02 | bandit B324, semgrep |
| VULN-06 | Flask debug / bind 0.0.0.0 | A05 | bandit B201/B104, semgrep |
| VULN-07 | Dependencias con CVEs | A06 | pip-audit, trivy, dependabot |

## Paso a paso

### 1. Subir a GitHub
```bash
gh repo create devsecops-lab --private --source . --push
# o: git remote add origin git@github.com:<usuario>/devsecops-lab.git && git push -u origin main
```
Ir a **Actions**: `ci` deberia pasar los tests pero fallar en Trivy; `security` deberia fallar en
todos sus jobs. Eso es lo esperado: **el pipeline esta haciendo su trabajo**.

### 2. Proteger main
Settings -> Branches -> Add rule `main`:
- Require a pull request before merging
- Require status checks: `Lint + Tests`, `Secrets (gitleaks)`, `SAST (bandit + semgrep)`, `SCA (pip-audit)`
- Settings -> Code security: activar **Dependabot alerts**, **Secret scanning** y **Push protection**

### 3. Entorno local
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pipx install "bandit[toml]"; pipx install pip-audit; pipx install semgrep
pre-commit install
make test sast sca          # sin Docker
make secrets iac scan-image # con Docker
```

### 4. Ejercicio
Crear una rama `fix/vulns`, corregir una vulnerabilidad por commit, abrir un PR y ver como cada
job pasa a verde. Al corregir VULN-02 quitar el `@pytest.mark.xfail` del test de SQLi.
Pistas en los comentarios `Fix:` de `app/main.py`. Solucion en `soluciones/fixes.diff`.

### 5. Proximos pasos (mejora de proceso)
- Fijar cada `uses:` a un **commit SHA** (ver apuntes: incidente Trivy/TeamPCP marzo 2026).
- Subir resultados SARIF a *Code scanning* (gratis en repos publicos / con GHAS).
- Firmar la imagen con **cosign** y publicar el SBOM como attestation.
- Agregar **CodeQL** y **OpenSSF Scorecard**.
- DAST como gate (quitar `-I` en ZAP) contra un entorno de staging.
# prueba
# prueba
# prueba
