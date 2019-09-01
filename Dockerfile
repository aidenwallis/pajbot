FROM python:alpine3.9
RUN apk add --no-cache supervisor gcc musl-dev libffi-dev openssl-dev zlib-dev jpeg-dev git mysql-client
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
RUN chmod +x /app/docker/install/run.sh
CMD ["/app/docker/install/run.sh"]