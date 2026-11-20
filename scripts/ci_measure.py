#!/usr/bin/env python3
"""Stream xcodebuild output unchanged, retain timing evidence, and check successful-run coverage."""
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time

OUTPUT = Path('ci-diagnostics')
OUTPUT.mkdir(exist_ok=True)


def utc(epoch):
    return datetime.fromtimestamp(epoch, timezone.utc).isoformat()


def summary():
    phases = {p.stem: json.loads(p.read_text()) for p in OUTPUT.glob('*-timing.json')}
    data = {'shard': os.getenv('CI_SHARD'), 'runner': os.getenv('RUNNER_NAME'),
            'platform': platform.platform(), 'created_at': utc(time.time()), 'phases': phases}
    test = phases.get('test-timing')
    if test:
        data['post_test_before_diagnostics_upload_seconds'] = time.time() - test['finished_epoch']
    (OUTPUT / 'summary.json').write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps(data, indent=2))


def measure(phase, command):
    if command and command[0] == '--':
        command = command[1:]
    if not command:
        raise ValueError('Missing command')
    start = time.time()
    offset = datetime.now().astimezone().tzinfo
    record = {'phase': phase, 'started_at': utc(start), 'started_epoch': start,
              'runner_timezone': str(offset), 'command': command, 'suites': {}, 'test_cases': []}
    code = 127
    print(f'CI_PHASE_START {phase} {utc(start)}', flush=True)
    try:
        with (OUTPUT / f'{phase}.log').open('w') as log:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, errors='replace', bufsize=1)
            for line in process.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
                log.write(line)
                log.flush()
                now = time.time()
                suite = re.search(r"Test Suite '(EasyJournalTests|EasyJournalUITests)\.xctest' (started|passed|failed) at (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d(?:\.\d+)?)", line)
                if suite:
                    name, event, reported = suite.groups()
                    event = 'started' if event == 'started' else 'finished'
                    reported_epoch = datetime.fromisoformat(reported).replace(tzinfo=offset).timestamp()
                    record['suites'].setdefault(name, {})[event] = {
                        'observed_at': utc(now), 'observed_delay_seconds': now - start,
                        'reported_at': reported, 'reported_delay_seconds': reported_epoch - start,
                    }
                case = re.search(r"Test Case '-\[(EasyJournalTests|EasyJournalUITests)\.(\w+) (test\w+)\]' (passed|failed|skipped) \(([\d.]+) seconds\)", line)
                if case:
                    target, cls, method, outcome, seconds = case.groups()
                    record['test_cases'].append({'test': f'{target}/{cls}/{method}',
                        'outcome': outcome, 'seconds': float(seconds), 'observed_at': utc(now)})
            code = process.wait()
        if phase == 'test':
            selection = json.loads((OUTPUT / 'selection.json').read_text())
            expected = selection['core_tests'] + selection['ui_tests']
            counts = Counter(case['test'] for case in record['test_cases'])
            record['coverage'] = {
                'missing': sorted(set(expected) - set(counts)),
                'unexpected': sorted(set(counts) - set(expected)),
                'duplicates': sorted(name for name, count in counts.items() if count != 1),
                'not_passed': [c['test'] for c in record['test_cases'] if c['outcome'] != 'passed'],
            }
            if code == 0 and any(record['coverage'].values()):
                print('::error::Successful xcodebuild did not report each selected test exactly once as passed', flush=True)
                code = 1
    finally:
        end = time.time()
        record.update(finished_at=utc(end), finished_epoch=end, seconds=end - start, exit_code=code)
        (OUTPUT / f'{phase}-timing.json').write_text(json.dumps(record, indent=2) + '\n')
        print(f'CI_PHASE_END {phase} {utc(end)} seconds={end-start:.3f} exit={code}', flush=True)
    return code


if __name__ == '__main__':
    if sys.argv[1:] == ['summary']:
        summary()
    else:
        phase = sys.argv[1]
        if phase not in ['build', 'test']:
            raise ValueError('Expected build/test/summary')
        sys.exit(measure(phase, sys.argv[2:]))
