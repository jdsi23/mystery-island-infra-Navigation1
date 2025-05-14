# navigation-app/Dockerfile

FROM python:3.11-slim

# Install Nginx
RUN apt-get update && \
    apt-get install -y nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application files and static assets
COPY . /app
COPY static/ /app/static/

# Install Python dependencies
RUN pip install flask

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80 for Flask app (proxied by Nginx)
EXPOSE 80

# Make startup script executable
RUN chmod +x start.sh

# Start both Nginx and Flask app
CMD ["./start.sh"]
