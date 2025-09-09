FROM python:3.12-alpine

WORKDIR /usr/src/app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 8099

CMD ["python", "app.py"]
