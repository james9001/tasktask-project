#!/bin/sh

# Clone the backend and frontend repositories to sibling directories of this repository's dir
cd ..
git clone https://github.com/james9001/tasktask-frontend.git
git clone https://github.com/james9001/tasktask-backend.git

# Build the frontend container image, with sudo
cd tasktask-frontend
sudo docker build -t tasktask-frontend:latest .
cd ..

# Build the backend container image
cd tasktask-backend
sudo docker build -t tasktask-backend:latest .
cd ..

# Come back to tasktask-project
cd tasktask-project

# Create local data directory for the Postgres container
mkdir -p ./localdev/postgres

# And finally, bring up the stack
sudo docker compose up -d --remove-orphans
