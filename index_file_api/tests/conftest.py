"""
Configure pytest environment for index_file_api tests.
"""
import os
import sys
from pathlib import Path

# Add the parent directory (index_file_api) to sys.path
parent_dir = str(Path(__file__).parent.parent)
sys.path.insert(0, parent_dir)

# Add the root directory to sys.path so 'core' can be imported
root_dir = str(Path(__file__).parent.parent.parent)
sys.path.insert(0, root_dir)

# Print sys.path for debugging
print(f"sys.path in conftest: {sys.path}")

# Print environment variables for debugging
print(f"PYTHONPATH: {os.environ.get('PYTHONPATH', 'not set')}")