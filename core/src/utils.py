from urllib.parse import urlparse

def get_file_name_from_url(url: str) -> str:
    parsed_url = urlparse(url)
    path = parsed_url.path
    file_name = path.split("/")[-1]
    return file_name

def is_file_type(file_path: str, file_type: str) -> bool:
    return file_path.endswith(file_type)
