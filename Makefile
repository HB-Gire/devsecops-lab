# Atajos para correr localmente lo mismo que corre el pipeline ("shift-left").
# Uso: make help
IMAGE ?= devsecops-lab:local
REPORTS := reports

.PHONY: help venv install lint test secrets sast sca iac image scan-image sbom dast security all clean

help: ## Lista los targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

venv: ## Crea el entorno virtual
	python3 -m venv .venv && . .venv/bin/activate && pip install -U pip

install: ## Instala dependencias de dev y hooks de pre-commit
	pip install -r requirements-dev.txt && pre-commit install

lint: ## Lint (ruff)
	ruff check .

test: ## Tests unitarios + cobertura
	pytest --cov=app --cov-report=term-missing

secrets: ## Secret scanning (gitleaks, via Docker)
	docker run --rm -v "$(PWD):/repo" ghcr.io/gitleaks/gitleaks:v8.30.1 dir /repo -v

sast: ## SAST: bandit + semgrep
	@mkdir -p $(REPORTS)
	bandit -r app -f txt
	semgrep scan --metrics=off --config .semgrep/rules.yml --config p/python --config p/flask --error app

sca: ## SCA: dependencias con CVEs
	pip-audit -r requirements.txt

iac: ## Lint de Dockerfile (hadolint) + misconfig (trivy config)
	docker run --rm -i hadolint/hadolint:v2.12.0 < Dockerfile
	docker run --rm -v "$(PWD):/src" aquasec/trivy:0.69.3 config /src

image: ## Construye la imagen
	docker build -t $(IMAGE) .

scan-image: image ## Escanea la imagen (CVEs de SO + librerias)
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.69.3 image --severity HIGH,CRITICAL $(IMAGE)

sbom: image ## Genera SBOM CycloneDX de la imagen
	@mkdir -p $(REPORTS)
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$(PWD)/$(REPORTS):/out" anchore/syft:latest $(IMAGE) -o cyclonedx-json=/out/sbom.cdx.json

dast: image ## DAST: levanta la app y corre OWASP ZAP baseline
	docker network create lab-net 2>/dev/null || true
	docker run -d --rm --name lab-app --network lab-net $(IMAGE)
	sleep 3
	-docker run --rm --network lab-net -v "$(PWD):/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t http://lab-app:8080 -r $(REPORTS)/zap.html -I
	docker stop lab-app

security: secrets sast sca iac ## Todos los chequeos estaticos de seguridad

all: lint test security ## Lint + tests + seguridad

clean: ## Limpia artefactos
	rm -rf $(REPORTS) .pytest_cache .ruff_cache .coverage
