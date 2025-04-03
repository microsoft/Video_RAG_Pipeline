#!/bin/bash

# Check if virtual environment exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
elif [ -d ".venv" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
fi

# Export requirements
echo "Exporting Python dependencies to requirements.txt..."
pip freeze > requirements.txt

echo "Requirements exported successfully to requirements.txt"

# Deactivate virtual environment if it was activated
if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
fi
