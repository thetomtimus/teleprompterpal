#!/usr/bin/env python3
"""Bind an explicit help review to app sources; no network or translation API calls."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REVIEW = Path('docs/help-sync-review.json')
LOCALES = ['en', 'es', 'de', 'fr', 'pt-BR', 'ja', 'ko']
APP_TREES = (
    'iPhoneApp', 'iPhonePrototype/App', 'iPhonePrototype/Support/Sources',
    'Packages/PhoneLibrary/Sources', 'Packages/TeleprompterCore/Sources/PromptingCore',
)
APP_FILES = (
    'project.yml', 'Packages/PhoneLibrary/Package.swift',
    'Packages/TeleprompterCore/Package.swift', 'iPhonePrototype/Support/Package.swift',
)
GUIDE_TREES = ('Marketing/src/i18n', 'Marketing/src/pages/help', 'Marketing/public/images/help')
GUIDE_FILES = (
    'Marketing/src/components/HelpMedia.astro',
    'Marketing/src/data/help.mjs', 'Marketing/src/layouts/HelpLayout.astro',
    'Marketing/src/lib/help-search.mjs', 'Marketing/src/styles/help.css',
    'Marketing/public/images/scripts.webp', 'Marketing/public/images/editor.webp',
    'Marketing/public/images/reader-settings.webp',
)
EXCLUDED = {'iPhonePrototype/App/PrototypeEntry.swift', 'iPhonePrototype/App/Info.plist'}


class ReviewError(Exception):
    pass


def fingerprint(root: Path, trees, files) -> dict[str, str]:
    paths = set()
    for name in trees:
        directory = root / name
        if not directory.is_dir():
            raise ReviewError(f'Missing reviewed source directory: {name}')
        paths.update(p for p in directory.rglob('*') if p.is_file()
                     and not any(part.startswith('.') or part == '__pycache__'
                                 for part in p.relative_to(directory).parts)
                     and p.suffix.lower() != '.md')
    for name in files:
        path = root / name
        if not path.is_file():
            raise ReviewError(f'Missing reviewed source file: {name}')
        paths.add(path)
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths) if p.relative_to(root).as_posix() not in EXCLUDED}


def snapshot(root: Path) -> dict:
    return {'app': fingerprint(root, APP_TREES, APP_FILES),
            'guide': fingerprint(root, GUIDE_TREES, GUIDE_FILES)}


def changed_paths(before: dict, after: dict) -> list[str]:
    return sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))


def read_review(root: Path) -> dict:
    try:
        data = json.loads((root / REVIEW).read_text())
        if (data['version'] != 1 or data['locales'] != LOCALES
                or data['outcome'] not in ('updated', 'no-help-change', 'initial-review')
                or len(data['reason'].strip()) < 20 or len(data['screenshots'].strip()) < 20
                or not data['articles'] or data['validation'] != 'build-and-help-tests-passed'
                or not all(isinstance(data['snapshot'][key], dict) and data['snapshot'][key]
                           for key in ('app', 'guide'))):
            raise ValueError('Invalid review fields')
        return data
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ReviewError(f'Help review is missing or invalid. Follow docs/help-sync.md. ({error})') from error


def check(root: Path) -> dict:
    review = read_review(root)
    current = snapshot(root)
    changed = {key: changed_paths(review['snapshot'][key], current[key]) for key in current}
    if any(changed.values()):
        detail = '\n'.join(f'  {key}: {path}' for key, paths in changed.items() for path in paths)
        raise ReviewError('App/help changes have not been reviewed together:\n' + detail
                          + '\nUpdate affected help and all six translations, review screenshots, then run '
                            'the record command in docs/help-sync.md. Internal-only changes require a reason.')
    return review


def record(root: Path, outcome: str, reason: str, screenshots: str, articles: list[str]) -> dict:
    if len(reason.strip()) < 20 or len(screenshots.strip()) < 20 or not articles:
        raise ReviewError('Provide a specific reason, screenshot assessment, and affected article slugs.')
    exists = (root / REVIEW).exists()
    if (outcome == 'initial-review') == exists:
        raise ReviewError('initial-review is only for the first baseline; subsequent reviews use updated or no-help-change.')
    before = snapshot(root)
    if exists:
        previous = read_review(root)
        if outcome == 'updated' and previous['snapshot']['guide'] == before['guide']:
            raise ReviewError('updated requires an actual help, screenshot, or translation change.')
    node, npm = shutil.which('node'), shutil.which('npm')
    if not node or not npm:
        raise ReviewError('Node 22.22+ or 24 and npm are required to validate all seven help languages.')
    marketing = root / 'Marketing'
    context = json.loads(subprocess.check_output([
        node, '--input-type=module', '-e',
        "import {helpArticles} from './src/data/help.mjs'; import {locales} from './src/i18n/config.mjs'; "
        "console.log(JSON.stringify({articles:helpArticles.map(a=>a.slug),locales:locales.map(l=>l.code)}));"
    ], cwd=marketing, text=True))
    if context['locales'] != LOCALES or not set(articles).issubset({'overview', *context['articles']}):
        raise ReviewError('Review must cover the configured seven locales and valid current help article slugs.')
    subprocess.run([npm, 'run', 'build'], cwd=marketing, check=True)
    subprocess.run([node, '--test', 'tests/i18n.test.mjs', 'tests/help.test.mjs'], cwd=marketing, check=True)
    if snapshot(root) != before:
        raise ReviewError('App or help files changed during validation. Review the new changes and run record again.')
    review = {'version': 1, 'reviewed_at': datetime.now(timezone.utc).isoformat(),
              'outcome': outcome, 'reason': reason.strip(), 'screenshots': screenshots.strip(),
              'articles': articles, 'locales': LOCALES, 'validation': 'build-and-help-tests-passed',
              'snapshot': before}
    path = root / REVIEW
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(review, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)
    return review


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('check', help='Fail when current app/help content differs from the last validated review.')
    update = commands.add_parser('record', help='After reviewing app/help changes, build and test all locales, then save the review.')
    update.add_argument('--outcome', choices=['updated', 'no-help-change', 'initial-review'], required=True)
    update.add_argument('--reason', required=True)
    update.add_argument('--screenshots', required=True)
    update.add_argument('--articles', nargs='+', required=True)
    args = parser.parse_args()
    try:
        review = check(ROOT) if args.command == 'check' else record(
            ROOT, args.outcome, args.reason, args.screenshots, args.articles)
    except (ReviewError, subprocess.CalledProcessError) as error:
        print(f'Help sync: {error}', file=sys.stderr)
        return 1
    print(f"Help sync passed: {len(review['snapshot']['app'])} app files; seven languages; {review['outcome']}.")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
