"""Resolve static QuestieDB zone and quest-sort correction values."""
import re


def enum_symbols(source):
    return {key: int(value) for key, value in re.findall(
        r'^[ \t]*([A-Z][A-Z_0-9]+)[ \t]*=[ \t]*(-?\d+)[ \t]*,?[ \t]*(?:--[^\n]*)?$', source, re.M)}


def resolve_category(expression, zones, sorts):
    if re.fullmatch(r'-?\d+', expression):
        return int(expression)
    prefix, _, key = expression.partition('.')
    return (zones if prefix == 'zoneIDs' else sorts if prefix == 'sortKeys' else {}).get(key)


def apply_categories(source, categories, zones, sorts):
    blocks = list(re.finditer(r'^        \[(\d+)\]\s*=\s*\{', source, re.M))
    for i, match in enumerate(blocks):
        block = source[match.end():blocks[i+1].start() if i+1 < len(blocks) else len(source)]
        value = re.search(r'\[questKeys.zoneOrSort\]\s*=\s*(-?\d+|zoneIDs\.\w+|sortKeys\.\w+)\s*[,\n]', block)
        if value:
            resolved = resolve_category(value.group(1), zones, sorts)
            if resolved is not None:
                categories[int(match.group(1))] = resolved


def sort_labels(sorts):
    classes = {'WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID', 'MONK', 'DEATHKNIGHT'}
    return {value: ('Death Knight' if key == 'DEATHKNIGHT' else key.replace('_', ' ').title())
            + (' quests' if key in classes else '') for key, value in sorts.items()}
