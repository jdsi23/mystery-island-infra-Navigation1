FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install flask
EXPOSE 5001
CMD ["python", "app.py"]