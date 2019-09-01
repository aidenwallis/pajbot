FROM python:alpine3.9
RUN apk add --no-cache supervisor gcc musl-dev libffi-dev openssl-dev zlib-dev jpeg-dev git
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD ["/usr/bin/supervisord", "-c", "/app/docker/supervisord.conf"]