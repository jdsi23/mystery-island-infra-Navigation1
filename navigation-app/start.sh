#!/bin/bash

# Start Nginx in the background
nginx

# Start Flask app in the foreground (keeps the container alive)
python3 app.py
