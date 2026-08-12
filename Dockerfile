FROM python:3.14-slim
WORKDIR /app

# Install the Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the project code
COPY . .

# Default: show the steps. Real runs use e.g.  docker compose run --rm app python -m src.bronze
CMD ["python", "-c", "print('Run a step, e.g.: docker compose run --rm app python -m src.bronze')"]
