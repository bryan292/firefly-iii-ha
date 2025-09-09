FROM python:3.12-alpine

# Set the working directory
WORKDIR /app

# Copy requirements first for better caching
COPY app/requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY app/ /app/

# Make run.sh executable
COPY run.sh /
RUN chmod +x /run.sh

EXPOSE 8099

# Use run.sh as entrypoint
CMD ["/run.sh"]
