# Use an official Python runtime as a parent image
FROM python:3.10-alpine

# Set the working directory in the container to /my_app
WORKDIR /Noteapp

# Add the current directory contents into the container at /app
COPY . /Noteapp

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Make port 5000 available to the world outside this container
EXPOSE 8000

WORKDIR /Noteapp/app

# Run app.py when the container launches
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "wsgi:app"]
