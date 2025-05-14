FROM python:3.11-slim

# Install nginx
RUN apt-get update && \
    apt-get install -y nginx unzip curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Terraform
WORKDIR /tmp
RUN curl -O https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip && \
    unzip terraform_1.7.5_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.7.5_linux_amd64.zip

# Set app directory
WORKDIR /app

# Copy app files
COPY . /app
COPY static/ /app/static/

# Install Python dependencies
RUN pip install flask

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Expose app port
EXPOSE 80

# Make script executable
RUN chmod +x start.sh

# Start app
CMD ["./start.sh"]
