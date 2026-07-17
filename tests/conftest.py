import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_GEN_DIR = PROJECT_ROOT / "data_generation"

sys.path.insert(0, str(DATA_GEN_DIR))


@pytest.fixture(scope="session")
def project_root() -> Path:
    return PROJECT_ROOT
