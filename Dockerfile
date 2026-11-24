# ---- build stage ----
FROM python:3.12-slim AS build
WORKDIR /w
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- runtime stage (optimized) ----
FROM python:3.12-alpine
WORKDIR /app
COPY --from=build /install /usr/local
COPY app/app.py .
RUN adduser -D appuser
USER appuser
EXPOSE 5000
CMD ["gunicorn", "-b", "0.0.0.0:5000", "-w", "2", "--threads", "4", "app:app"]
