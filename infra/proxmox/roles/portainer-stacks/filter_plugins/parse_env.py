"""Custom filter to parse .env format into Portainer env list."""


def parse_env(content):
    """
    Parse .env format content into list of {name, value} dicts.

    Handles:
    - Comments (lines starting with #)
    - Empty lines
    - Quoted values (single or double quotes)
    """
    if not content:
        return []

    result = []
    for line in content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' not in line:
            continue
        key, val = line.split('=', 1)
        val = val.strip()
        # Strip surrounding quotes
        if (val.startswith('"') and val.endswith('"')) or \
           (val.startswith("'") and val.endswith("'")):
            val = val[1:-1]
        result.append({'name': key.strip(), 'value': val})
    return result


class FilterModule:
    """Ansible filter plugin."""

    def filters(self):
        return {
            'parse_env': parse_env
        }
