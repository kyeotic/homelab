"""Custom filters for portainer-stacks role."""

import re


def parse_env(content):
    """
    Parse .env format content into list of {name, value} dicts.

    Handles:
    - Comments (lines starting with #)
    - Empty lines
    - Quoted values (single or double quotes)
    - 'export' prefix (e.g., export VAR=value)
    - Inline comments (e.g., VAR=value # comment)
    - Escaped quotes within values
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

        # Strip 'export ' prefix if present
        if line.startswith('export '):
            line = line[7:]

        key, val = line.split('=', 1)
        key = key.strip()
        val = val.strip()

        # Handle quoted values (preserving escaped quotes inside)
        if val.startswith('"') and '"' in val[1:]:
            # Find the closing quote, accounting for escaped quotes
            match = re.match(r'^"((?:[^"\\]|\\.)*)"', val)
            if match:
                val = match.group(1)
                # Unescape escaped quotes
                val = val.replace('\\"', '"')
            else:
                # Fallback: strip outer quotes
                val = val[1:val.rfind('"')] if val.rfind('"') > 0 else val[1:]
        elif val.startswith("'") and "'" in val[1:]:
            # Single quotes don't support escaping in shell
            end_quote = val.rfind("'")
            if end_quote > 0:
                val = val[1:end_quote]
            else:
                val = val[1:]
        else:
            # Unquoted value - strip inline comments
            if ' #' in val:
                val = val[:val.index(' #')].rstrip()

        result.append({'name': key, 'value': val})
    return result


def stack_needs_update(stack_name, current_files, existing_stacks, new_content, new_env):
    """
    Determine if a stack needs to be updated by comparing current vs new state.

    Returns dict with:
    - content_changed: bool
    - env_changed: bool
    - exists: bool
    """
    # Find current content from API response
    current_content = ''
    for result in current_files:
        if result.get('item', {}).get('name') == stack_name and 'json' in result:
            current_content = result['json'].get('StackFileContent', '')
            break

    # Find current env from existing stacks
    current_env = []
    for stack in existing_stacks:
        if stack.get('Name') == stack_name:
            current_env = stack.get('Env', [])
            break

    # Sort env lists for comparison
    current_sorted = sorted(current_env, key=lambda x: x.get('name', ''))
    new_sorted = sorted(new_env, key=lambda x: x.get('name', ''))

    return {
        'content_changed': current_content != new_content,
        'env_changed': current_sorted != new_sorted,
        'exists': bool(current_content)
    }


class FilterModule:
    """Ansible filter plugin."""

    def filters(self):
        return {
            'parse_env': parse_env,
            'stack_needs_update': stack_needs_update
        }
