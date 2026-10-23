#!/usr/bin/env python3
"""Regression tests for the release gate; test files never touch the real app."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import help_sync as sync


class HelpSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for tree in (*sync.APP_TREES, *sync.GUIDE_TREES):
            self.write(tree + '/example.swift', 'baseline')
        for name in (*sync.APP_FILES, *sync.GUIDE_FILES):
            self.write(name, 'baseline')
        self.baseline = {'version': 1, 'reviewed_at': '2026-10-24T00:00:00+00:00',
                         'outcome': 'initial-review', 'reason': 'Initial app and manual content review.',
                         'screenshots': 'Existing screenshots still match the reviewed app controls.',
                         'articles': ['create-a-script'], 'locales': sync.LOCALES,
                         'validation': 'build-and-help-tests-passed', 'snapshot': sync.snapshot(self.root)}
        self.write(sync.REVIEW, json.dumps(self.baseline))

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_current_review_passes(self):
        self.assertEqual(sync.check(self.root)['outcome'], 'initial-review')

    def test_release_build_hook_blocks_drift_but_debug_iteration_remains_available(self):
        # Execute the shipping shell hook against an isolated copy of the checker.
        checker = self.write('Scripts/help_sync.py', (sync.ROOT / 'Scripts/help_sync.py').read_text())
        hook = sync.ROOT / 'Scripts/check-help-release.sh'
        environment = {**os.environ, 'SRCROOT': str(self.root), 'CONFIGURATION': 'Release'}
        result = subprocess.run(['/bin/sh', str(hook)], env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.write('iPhoneApp/example.swift', 'a changed user-facing control')
        result = subprocess.run(['/bin/sh', str(hook)], env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not been reviewed together', result.stderr)
        environment['CONFIGURATION'] = 'Debug'
        result = subprocess.run(['/bin/sh', str(hook)], env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_app_edits_additions_and_deletions_require_review(self):
        for operation in ('edit', 'add', 'delete'):
            with self.subTest(operation=operation):
                path = self.root / 'iPhoneApp/example.swift'
                extra = self.root / 'iPhoneApp/NewFeature.swift'
                if operation == 'edit': path.write_text('changed behavior')
                if operation == 'add': extra.write_text('new behavior')
                if operation == 'delete': path.unlink()
                with self.assertRaisesRegex(sync.ReviewError, 'not been reviewed together'):
                    sync.check(self.root)
                path.write_text('baseline')
                extra.unlink(missing_ok=True)

    def test_shared_phone_services_and_help_translations_are_watched(self):
        for name in ['iPhonePrototype/Support/Sources/example.swift',
                     'Packages/PhoneLibrary/Sources/example.swift',
                     'Marketing/src/data/help.mjs', 'Marketing/src/i18n/ko.json',
                     'Marketing/public/images/help/new-control.png']:
            with self.subTest(path=name):
                path = self.root / name
                old = path.read_text() if path.exists() else None
                self.write(name, 'changed')
                with self.assertRaises(sync.ReviewError): sync.check(self.root)
                if old is None: path.unlink()
                else: path.write_text(old)

    def test_tests_docs_mac_and_generated_caches_do_not_invalidate_review(self):
        for name in ['iPhoneApp/README.md', 'iPhoneAppTests/Example.swift',
                     'PrivatePresenterApp/Example.swift', 'iPhoneApp/.DS_Store',
                     'iPhoneApp/__pycache__/example.pyc', 'iPhonePrototype/App/PrototypeEntry.swift']:
            self.write(name, 'unrelated change')
        sync.check(self.root)

    def test_missing_or_incomplete_review_cannot_pass(self):
        path = self.root / sync.REVIEW
        for value in ('{}', '{broken', json.dumps({**self.baseline, 'locales': ['en']})):
            path.write_text(value)
            with self.assertRaises(sync.ReviewError): sync.check(self.root)
        path.unlink()
        with self.assertRaises(sync.ReviewError): sync.check(self.root)

    def test_updated_outcome_needs_documentation_changes(self):
        with self.assertRaisesRegex(sync.ReviewError, 'actual help'):
            sync.record(self.root, 'updated', 'Changed the reader behavior for users.',
                        'Reviewed the actual app screenshots and their labels.', ['create-a-script'])

    @patch('help_sync.shutil.which', side_effect=lambda name: name)
    @patch('help_sync.subprocess.check_output')
    @patch('help_sync.subprocess.run')
    def test_failed_translation_build_does_not_refresh_review(self, run, output, which):
        output.return_value = json.dumps({'articles': ['create-a-script'], 'locales': sync.LOCALES})
        run.side_effect = subprocess.CalledProcessError(1, ['npm', 'run', 'build'])
        previous = (self.root / sync.REVIEW).read_text()
        self.write('iPhoneApp/example.swift', 'new behavior')
        with self.assertRaises(subprocess.CalledProcessError):
            sync.record(self.root, 'no-help-change', 'Internal performance fix; user steps are unchanged.',
                        'Existing screenshots and app controls remain unchanged.', ['create-a-script'])
        self.assertEqual((self.root / sync.REVIEW).read_text(), previous)
        with self.assertRaises(sync.ReviewError): sync.check(self.root)

    @patch('help_sync.shutil.which', side_effect=lambda name: name)
    @patch('help_sync.subprocess.check_output')
    @patch('help_sync.subprocess.run')
    def test_files_changing_during_validation_cannot_be_stamped(self, run, output, which):
        output.return_value = json.dumps({'articles': ['create-a-script'], 'locales': sync.LOCALES})
        run.side_effect = lambda *args, **kwargs: self.write('iPhoneApp/example.swift', 'concurrent edit')
        with self.assertRaisesRegex(sync.ReviewError, 'changed during validation'):
            sync.record(self.root, 'no-help-change', 'Internal performance fix; user steps are unchanged.',
                        'Existing screenshots and app controls remain unchanged.', ['create-a-script'])
        self.assertEqual(json.loads((self.root / sync.REVIEW).read_text()), self.baseline)

    @patch('help_sync.shutil.which', side_effect=lambda name: name)
    @patch('help_sync.subprocess.check_output')
    @patch('help_sync.subprocess.run')
    def test_successful_review_stamps_current_files_after_both_checks(self, run, output, which):
        output.return_value = json.dumps({'articles': ['create-a-script'], 'locales': sync.LOCALES})
        self.write('iPhoneApp/example.swift', 'internal fix')
        sync.record(self.root, 'no-help-change', 'Internal performance fix; user steps are unchanged.',
                    'Existing screenshots and app controls remain unchanged.', ['create-a-script'])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(sync.check(self.root)['outcome'], 'no-help-change')


if __name__ == '__main__':
    unittest.main()
