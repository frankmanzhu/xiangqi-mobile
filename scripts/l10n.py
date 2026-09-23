#!/usr/bin/env python3
"""Keep the typed Swift string keys in sync with the localization files.

en.lproj/Localizable.strings is the source of truth for the key set, its
English fallback text, and translator comments. zh-Hans.lproj and
zh-Hant.lproj hold translations of the same keys and are otherwise
independent files -- editing one language never touches another. This
script derives the typed `L10n` accessors from the English file and reports
translations that are missing or stale.

    scripts/l10n.py generate   # rewrite Strings+Generated.swift
    scripts/l10n.py check      # exit 1 on drift or missing translations
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALIZATIONS = os.path.join(ROOT, "Resources", "Localizations")
GENERATED = os.path.join(
    ROOT, "XiangqiMobile", "App", "Localization", "Strings+Generated.swift"
)
SOURCE_LANGUAGE = "en"
REQUIRED_LANGUAGES = ("en", "zh-Hans", "zh-Hant")

SWIFT_KEYWORDS = {
    "class", "default", "deinit", "enum", "extension", "func", "import", "in",
    "init", "internal", "let", "operator", "private", "protocol", "public",
    "repeat", "return", "self", "static", "struct", "subscript", "super",
    "switch", "var", "where", "while", "true", "false", "nil", "continue",
}

# Number of format placeholders, so call sites can be checked by the compiler.
PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?[@a-zA-Z]|%lld")

# A leading `/* comment */`, then a `"key" = "value";` entry.
ENTRY = re.compile(
    r"""(?:/\*\s*(?P<comment>.*?)\s*\*/\s*)?
        "(?P<key>(?:[^"\\]|\\.)*)"\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*;""",
    re.DOTALL | re.VERBOSE,
)


def unescape(value):
    return (
        value.replace('\\"', '"')
        .replace("\\n", "\n")
        .replace("\\\\", "\\")
    )


def strings_path(language):
    return os.path.join(LOCALIZATIONS, f"{language}.lproj", "Localizable.strings")


def load_strings(language):
    """Ordered dict of key -> (value, comment) for one language file."""
    path = strings_path(language)
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    entries = {}
    for match in ENTRY.finditer(text):
        key = unescape(match.group("key"))
        value = unescape(match.group("value"))
        comment = match.group("comment")
        entries[key] = (value, comment)
    return entries


def placeholder_count(value):
    """Highest positional index, or the count of sequential placeholders."""
    tokens = re.findall(r"%(?:(\d+)\$)?(?:lld|[@a-zA-Z])", value)
    if not tokens:
        return 0
    positional = [int(index) for index in tokens if index]
    return max(positional) if positional else len(tokens)


def identifier(segment):
    parts = re.split(r"[^0-9A-Za-z]+", segment)
    parts = [part for part in parts if part]
    if not parts:
        raise ValueError("empty key segment")
    head = parts[0]
    name = head[0].lower() + head[1:] + "".join(p[0].upper() + p[1:] for p in parts[1:])
    if name[0].isdigit():
        name = "_" + name
    return "`" + name + "`" if name in SWIFT_KEYWORDS else name


def type_name(segment):
    parts = [p for p in re.split(r"[^0-9A-Za-z]+", segment) if p]
    return "".join(p[0].upper() + p[1:] for p in parts)


def build_tree(source_strings):
    """Nest dotted keys, e.g. home.hero.title -> {home: {hero: {title: leaf}}}."""
    tree = {}
    for key in sorted(source_strings):
        node = tree
        segments = key.split(".")
        for segment in segments[:-1]:
            node = node.setdefault(segment, {})
            if not isinstance(node, dict):
                raise SystemExit(f"key '{key}' collides with a parent key")
        leaf = segments[-1]
        if leaf in node:
            raise SystemExit(f"key '{key}' collides with a nested namespace")
        english, comment = source_strings[key]
        node[leaf] = (key, english, comment)
    return tree


def escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def render(node, indent, lines):
    pad = "    " * indent
    for name in sorted(node):
        child = node[name]
        if isinstance(child, dict):
            lines.append(f"{pad}public enum {type_name(name)} {{")
            render(child, indent + 1, lines)
            lines.append(f"{pad}}}")
            lines.append("")
        else:
            key, english, comment = child
            count = placeholder_count(english)
            if comment:
                lines.append(f"{pad}/// {comment}")
            lines.append(f'{pad}/// English: "{escape(english)}"')
            lines.append(
                f'{pad}public static let {identifier(name)} = '
                f'LocalizedKey("{escape(key)}", en: "{escape(english)}"'
                + (f", arguments: {count}" if count else "")
                + ")"
            )
    while lines and lines[-1] == "":
        lines.pop()


def generate_source(source_strings):
    lines = [
        "// Generated by scripts/l10n.py from Resources/Localizations/en.lproj/Localizable.strings.",
        "// Do not edit by hand: edit that file and re-run `scripts/l10n.py generate`.",
        "",
        "// swiftlint:disable all",
        "",
        "public enum L10n {",
    ]
    body = []
    render(build_tree(source_strings), 1, body)
    lines.extend(body)
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def missing_translations(source_strings):
    problems = []
    source_keys = set(source_strings)
    for language in REQUIRED_LANGUAGES:
        if language == SOURCE_LANGUAGE:
            continue
        translations = load_strings(language)
        for key in sorted(source_keys):
            value, _ = translations.get(key, ("", None))
            if not value:
                problems.append(f"{key}: missing {language}")
        for key in sorted(set(translations) - source_keys):
            problems.append(f"{key}: {language} has no {SOURCE_LANGUAGE} source")
    return problems


def unused_keys(source_strings):
    """Keys the app never references, found by scanning for the generated path."""
    used = set()
    swift_root = os.path.join(ROOT, "XiangqiMobile")
    for directory, _, files in os.walk(swift_root):
        for name in files:
            if not name.endswith(".swift") or name == "Strings+Generated.swift":
                continue
            with open(os.path.join(directory, name), encoding="utf-8") as handle:
                text = handle.read()
            for match in re.finditer(r"L10n(?:\.[A-Za-z0-9_`]+)+", text):
                used.add(match.group(0))
    declared = {}
    for key in source_strings:
        segments = key.split(".")
        accessor = identifier(segments[-1]).strip("`")
        path = "L10n" + "".join("." + type_name(s) for s in segments[:-1]) + "." + accessor
        declared[key] = path
    return sorted(key for key, path in declared.items() if path not in used)


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "generate"
    source_strings = {
        key: (value, comment)
        for key, (value, comment) in load_strings(SOURCE_LANGUAGE).items()
    }
    source = generate_source(source_strings)

    if command == "generate":
        os.makedirs(os.path.dirname(GENERATED), exist_ok=True)
        with open(GENERATED, "w", encoding="utf-8") as handle:
            handle.write(source)
        print(f"Generated {len(source_strings)} keys -> {os.path.relpath(GENERATED, ROOT)}")
        problems = missing_translations(source_strings)
        if problems:
            print(f"warning: {len(problems)} untranslated entries")
        return 0

    if command == "check":
        failures = []
        existing = ""
        if os.path.exists(GENERATED):
            with open(GENERATED, encoding="utf-8") as handle:
                existing = handle.read()
        if existing != source:
            failures.append(
                "Strings+Generated.swift is stale; run `scripts/l10n.py generate`"
            )
        failures.extend(missing_translations(source_strings))
        for key in unused_keys(source_strings):
            failures.append(f"{key}: not referenced by any view")
        if failures:
            for failure in failures:
                print(f"error: {failure}", file=sys.stderr)
            return 1
        print(f"{len(source_strings)} keys: translated, referenced, and in sync.")
        return 0

    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
