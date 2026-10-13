# Dockerfile de referencia con buenas practicas (plantilla reutilizable):
#  - imagen base slim y con tag fijo (idealmente fijar tambien el digest @sha256:...)
#  - multi-stage: las herramientas de build no llegan a la imagen final
#  - usuario no-root
#  - sin cache de pip, sin secretos en capas
#  - HEALTHCHECK y servidor WSGI de produccion (gunicorn), no el server de debug de Flask

FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
LABEL org.opencontainers.image.source="https://github.com/OWNER/devsecops-lab" \
      org.opencontainers.image.description="DevSecOps lab app"
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_PATH=/tmp/lab.db
RUN groupadd --system app && useradd --system --gid app --no-create-home app
COPY --from=build /install /usr/local
WORKDIR /srv
COPY --chown=app:app app/ ./app/
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health').status==200 else 1)"
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app.main:app"]
