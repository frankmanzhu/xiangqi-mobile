#!/usr/bin/env python3
"""Verify distributable resources without signing or Apple membership."""
from pathlib import Path
import hashlib
import json
import plistlib
import sqlite3
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


source = json.loads((ROOT / 'Resources/Learning/CCPD-source.json').read_text())
database = ROOT / 'Resources/Learning/ccpd.sqlite3'
require(digest(database) == source['bundledDatabase']['databaseSHA256'], 'Learning database checksum changed')
with sqlite3.connect(database.as_uri() + '?mode=ro', uri=True) as db:
    require(db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok', 'Learning database is corrupt')
    metadata = dict(db.execute('SELECT key, value FROM metadata'))
    count = db.execute('SELECT COUNT(*) FROM records').fetchone()[0]
    require(count == source['bundledDatabase']['recordCount'] == sum(entry['records'] for entry in source['bundledDatabase']['sources']), 'Unexpected learning record count')
    require(metadata['source_revision'] == source['pinnedRevision'], 'Learning source revision changed')

revision = subprocess.check_output(['git', '-C', str(ROOT / 'Vendor/Pikafish'), 'rev-parse', 'HEAD'], text=True).strip()
client = (ROOT / 'XiangqiMobile/App/PikafishComputerClient.swift').read_text()
require(f'static let revision = "{revision}"' in client, 'Engine revision differs from app metadata')
require('!TARGET_OS_IPHONE' in (ROOT / 'Vendor/Pikafish/src/shm.h').read_text(), 'Apply EngineBridge/Patches/pikafish-ios-local-memory.patch before building iOS')
network_hash = digest(ROOT / 'Resources/Engine/pikafish.nnue')
require(f'static let networkSHA256 = "{network_hash}"' in client, 'NNUE checksum differs from app metadata')
require(network_hash in (ROOT / 'Resources/Licenses/Pikafish-NNUE-NOTICE.txt').read_text(), 'NNUE notice does not identify bundled weights')
with (ROOT / 'Resources/PrivacyInfo.xcprivacy').open('rb') as file:
    privacy = plistlib.load(file)
require(privacy['NSPrivacyTracking'] is False, 'Unexpected tracking declaration')
require(privacy['NSPrivacyCollectedDataTypes'] == [], 'Privacy disclosures need review')
require(any(api['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPICategoryUserDefaults' and 'CA92.1' in api['NSPrivacyAccessedAPITypeReasons'] for api in privacy['NSPrivacyAccessedAPITypes']), 'Missing UserDefaults API reason')
project = (ROOT / 'XiangqiMobile.xcodeproj/project.pbxproj').read_text()
for filename in ['PrivacyInfo.xcprivacy', 'Pikafish-GPL-3.0.txt', 'Pikafish-AUTHORS.txt', 'Pikafish-NNUE-NOTICE.txt', 'CCPD-CC-BY-4.0.txt', 'ccpd.sqlite3', 'pikafish.nnue']:
    require(f'{filename} in Resources' in project, f'{filename} is not in the resource build phase')
require((ROOT / 'docs/privacy-policy.md').exists(), 'Missing public privacy-policy source')
require((ROOT / 'docs/support.md').exists(), 'Missing support page source')
subprocess.run(['python3', str(ROOT / 'scripts/l10n.py'), 'check'], cwd=ROOT, check=True)
icon = ROOT / 'Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
info = subprocess.check_output(['sips', '-g', 'hasAlpha', '-g', 'pixelWidth', '-g', 'pixelHeight', str(icon)], text=True)
require('hasAlpha: no' in info and 'pixelWidth: 1024' in info and 'pixelHeight: 1024' in info, 'App icon must be opaque and 1024 × 1024')
print(f'Release resource checks passed: {count:,} games, pinned engine/NNUE, privacy declarations, licenses, localization, icon.')
print('WXF/Dongping redistribution rights remain undocumented; resource checks do not establish licensing clearance.')
print('Signing, hosted URLs, App Store Connect validation, on-device performance and VoiceOver still require separate checks.')
