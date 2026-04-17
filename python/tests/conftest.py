import pytest
from dparser import Parser


@pytest.fixture
def make_parser(tmp_path):
    def _factory(module, **kwargs):
        return Parser(modules=module, parser_folder=str(tmp_path), **kwargs)
    return _factory
