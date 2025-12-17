FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY sync.py .

# Create directories for config and data
RUN mkdir -p /config /data

# Run as non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app /config /data
USER appuser

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Run the sync script
CMD ["python", "-u", "sync.py"]
