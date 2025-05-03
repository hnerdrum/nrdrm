#!/bin/bash
set -e

# Run database migrations
echo "Running database migrations..."
diesel migration run

# Start the application
echo "Starting application..."
exec /app/identity