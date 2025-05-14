#!/bin/bash

# Start Nginx in the background
nginx -g 'daemon off;' &  # force background mode

# Start Flask app in the foreground (keeps the container alive)
python3 app.py
