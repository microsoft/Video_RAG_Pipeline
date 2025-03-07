import pytest
import sys
from pathlib import Path

# Ensure imports work by explicitly adding paths at the beginning of the test file
core_dir = str(Path(__file__).parent.parent.parent / 'core')
parent_dir = str(Path(__file__).parent.parent)
if core_dir not in sys.path:
    sys.path.insert(0, core_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

# Now try the import
from index_file_api.src import app

def test_app():
    assert False
