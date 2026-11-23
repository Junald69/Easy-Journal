#!/usr/bin/env python3
"""Fail closed if a UI XCTest is missing, duplicated, or no longer exists in the shard plan."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def discover(folder, target):
    tests = []
    for path in sorted(folder.rglob('*.swift')):
        source = path.read_text()
        # Current convention: one XCTestCase class per file. Reject unsupported layouts rather than omit them.
        methods = re.findall(r'\bfunc\s+(test\w+)\s*\(', source)
        if not methods:
            continue
        classes = re.findall(r'\bclass\s+(\w+)\s*:\s*XCTestCase\b', source)
        if len(classes) != 1:
            raise ValueError(f'{path}: expected one XCTestCase class; update discovery explicitly')
        tests.extend(f'{target}/{classes[0]}/{method}' for method in methods)
    if not tests or len(set(tests)) != len(tests):
        raise ValueError(f'{folder}: no tests or duplicate test identifiers')
    return tests


def validate(shards, discovered):
    if set(shards) != {'A', 'B'} or not all(isinstance(v, list) and v for v in shards.values()):
        raise ValueError('Expected exactly two nonempty shards A/B')
    assigned = shards['A'] + shards['B']
    duplicates = [name for name, count in Counter(assigned).items() if count != 1]
    missing = sorted(set(discovered) - set(assigned))
    stale = sorted(set(assigned) - set(discovered))
    if duplicates or missing or stale:
        raise ValueError(f'duplicates={duplicates}; unassigned={missing}; unknown={stale}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--shard', choices=['A', 'B'], required=True)
    parser.add_argument('--manifest', type=Path, default=ROOT / 'ci/ui-test-shards.json')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    ui = discover(ROOT / 'Tests/UITests', 'EasyJournalUITests')
    core = discover(ROOT / 'Tests/CoreTests', 'EasyJournalTests')
    validate(manifest['shards'], ui)
    selection = {
        'shard': args.shard,
        'ui_tests': manifest['shards'][args.shard],
        'core_tests': core if args.shard == 'A' else [],
        'all_ui_tests': ui,
        'estimated_seconds': manifest['estimated_seconds'][args.shard],
    }
    output = ROOT / 'ci-diagnostics'
    output.mkdir(exist_ok=True)
    (output / 'selection.json').write_text(json.dumps(selection, indent=2) + '\n')
    selectors = (['EasyJournalTests'] if args.shard == 'A' else []) + selection['ui_tests']
    (output / 'test-arguments.txt').write_text(''.join(f'-only-testing:{test}\n' for test in selectors))
    print(f'Validated {len(core)} Core tests; {len(ui)} UI tests; A={len(manifest["shards"]["A"])}, B={len(manifest["shards"]["B"])}; no overlap or omissions')
    print(json.dumps(selection, indent=2))


if __name__ == '__main__':
    main()
