const { test } = require('node:test');
const assert = require('node:assert/strict');
const { inspect, publish, plan, validateResult, sameVersion, allChecksSuccessful } = require('./review-merge.cjs');
const head = 'a'.repeat(40), base = 'b'.repeat(40), merge = 'c'.repeat(40);
const full_name = 'Junald69/Easy-Journal';
const context = { repo: { owner: 'Junald69', repo: 'Easy-Journal' }, runId: 123,
  eventName: 'pull_request_target', payload: { pull_request: { number: 10 } } };
const original = { eligible: true, number: 10, head, base, merge, ciRun: 90 };
const pass = JSON.stringify({ verdict: 'pass', summary: '指摘なし', findings: [] });

function fixture(overrides = {}) {
  const calls = [];
  const pr = { number: 10, state: 'open', draft: false, mergeable: true,
    changed_files: 1, merge_commit_sha: merge,
    base: { ref: 'main', sha: base, repo: { full_name } },
    head: { ref: 'feat/test', sha: head, repo: { full_name } }, ...overrides };
  const listFiles = async () => [{ filename: 'App/Feature.swift' }];
  const listWorkflowRuns = async () => [{ id: 90, head_sha: head, head_branch: 'feat/test',
    head_repository: { full_name }, status: 'completed', conclusion: 'success' }];
  const listJobsForWorkflowRun = async () => [{ name: 'シミュレーターでビルドとテスト',
    status: 'completed', conclusion: 'success' }];
  const github = {
    paginate: (fn, args) => fn(args),
    graphql: async () => ({ repository: { pullRequest: { reviewThreads: {
      nodes: [], pageInfo: { hasNextPage: false },
    } } } }),
    rest: {
      pulls: { get: async () => ({ data: pr }), listFiles,
        listReviews: async () => [], list: async () => [pr],
        merge: async args => { calls.push(['merge', args]); return { data: { merged: true, sha: 'd'.repeat(40) } }; } },
      repos: { compareCommitsWithBasehead: async () => ({ data: { status: 'ahead' } }),
        listCommitStatusesForRef: async () => [] },
      actions: { getWorkflow: async () => ({ data: { id: 5 } }), listWorkflowRuns,
        listJobsForWorkflowRun,
        createWorkflowDispatch: async args => { calls.push(['dispatch', args]); } },
      checks: { listForRef: async () => [{ status: 'completed', conclusion: 'success' }] },
      issues: { createComment: async args => { calls.push(['comment', args]); } },
    },
  };
  const summary = { addHeading() { return this; }, addRaw() { return this; }, async write() {} };
  return { github, context, core: { summary }, calls, pr };
}

test('valid pass merges only the reviewed SHA and starts main CI', async () => {
  const f = fixture();
  assert.equal((await publish({ ...f, original, raw: pass })).merged, true);
  assert.deepEqual(f.calls.map(x => x[0]), ['comment', 'merge', 'dispatch']);
  assert.equal(f.calls[1][1].sha, head);
  assert.equal(f.calls[1][1].merge_method, 'squash');
  assert.equal(f.calls[2][1].ref, 'main');
});

test('malformed, missing and uncertain review results cannot approve', () => {
  for (const raw of ['', '{}', 'null', '{"verdict":"pass"}', '{"verdict":"yes","summary":"ok","findings":[]}']) {
    assert.throws(() => validateResult(raw));
  }
  assert.equal(validateResult('{"verdict":"hold","summary":"不明","findings":[]}').canMerge, false);
});

test('even a low severity finding prevents merging despite a pass verdict', async () => {
  const f = fixture();
  const raw = JSON.stringify({ verdict: 'pass', summary: '確認', findings: [
    { severity: 'low', path: 'App/F.swift', line: 1, message: '問題' },
  ] });
  assert.equal((await publish({ ...f, original, raw })).merged, false);
  assert.deepEqual(f.calls.map(x => x[0]), ['comment']);
});

for (const [label, override] of [
  ['draft', { draft: true }], ['closed', { state: 'closed' }],
  ['fork', { head: { ref: 'feat/test', sha: head, repo: { full_name: 'someone/fork' } } }],
  ['wrong base', { base: { ref: 'develop', sha: base, repo: { full_name } } }],
  ['merge unknown', { mergeable: null }], ['conflict', { mergeable: false }],
]) {
  test(`${label} PR is ineligible`, async () => {
    assert.equal((await inspect(fixture(override), 10)).eligible, false);
  });
}

test('old head, old base and old CI result are rejected', async () => {
  for (const field of ['head', 'base', 'ciRun']) {
    const f = fixture();
    const old = { ...original, [field]: field === 'ciRun' ? 89 : 'e'.repeat(40) };
    assert.equal(sameVersion(old, original), false);
    assert.equal((await publish({ ...f, original: old, raw: pass })).merged, false);
    assert.deepEqual(f.calls.map(x => x[0]), ['comment']);
  }
});

test('a head update just before merge prevents the write', async () => {
  const f = fixture();
  let count = 0;
  f.github.rest.pulls.get = async () => ({ data: ++count === 1 ? f.pr : { ...f.pr, draft: true } });
  await assert.rejects(publish({ ...f, original, raw: pass }));
  assert.deepEqual(f.calls.map(x => x[0]), ['comment']);
});

test('CI/workflow changes and renamed workflow files require manual handling', async () => {
  for (const file of [{ filename: '.github/workflows/ci.yml' },
    { filename: 'old.yml', previous_filename: '.github/workflows/ci.yml' }]) {
    const f = fixture();
    f.github.rest.pulls.listFiles = async () => [file];
    assert.equal((await inspect(f, 10)).eligible, false);
  }
});

test('missing, failed, running CI and skipped build jobs cannot merge', async () => {
  for (const runs of [[], [{ id: 90, head_sha: head, head_branch: 'feat/test',
    head_repository: { full_name }, status: 'completed', conclusion: 'failure' }],
    [{ id: 90, head_sha: head, head_branch: 'feat/test',
      head_repository: { full_name }, status: 'in_progress', conclusion: null }]]) {
    const f = fixture();
    f.github.rest.actions.listWorkflowRuns = async () => runs;
    assert.equal((await inspect(f, 10)).eligible, false);
  }
  const f = fixture();
  f.github.rest.actions.listJobsForWorkflowRun = async () => [{
    name: 'シミュレーターでビルドとテスト', status: 'completed', conclusion: 'skipped',
  }];
  assert.equal((await inspect(f, 10)).eligible, false);
});

test('a branch missing latest main is held', async () => {
  const f = fixture();
  f.github.rest.repos.compareCommitsWithBasehead = async () => ({ data: { status: 'diverged' } });
  assert.equal((await inspect(f, 10)).eligible, false);
});

test('pending checks and commit statuses hold the merge', async () => {
  const f = fixture();
  f.github.rest.checks.listForRef = async () => [{ status: 'in_progress', conclusion: null }];
  assert.equal(await allChecksSuccessful(f, original), false);
  f.github.rest.checks.listForRef = async () => [];
  f.github.rest.repos.listCommitStatusesForRef = async () => [{ context: 'external', state: 'pending' }];
  assert.equal(await allChecksSuccessful(f, original), false);
});

test('unresolved review thread prevents merge', async () => {
  const f = fixture();
  f.github.graphql = async () => ({ repository: { pullRequest: { reviewThreads: {
    nodes: [{ isResolved: false }], pageInfo: { hasNextPage: false },
  } } } });
  assert.equal((await publish({ ...f, original, raw: pass })).merged, false);
  assert.deepEqual(f.calls.map(x => x[0]), ['comment']);
});

test('workflow_run finds PR even if GitHub omits pull_requests from its payload', async () => {
  const f = fixture();
  const ctx = { ...context, eventName: 'workflow_run', payload: { workflow_run: {
    event: 'pull_request', conclusion: 'success', head_sha: head,
    head_branch: 'feat/test', head_repository: { full_name }, pull_requests: [],
  } } };
  assert.equal((await plan({ ...f, context: ctx })).eligible, true);
  ctx.payload.workflow_run.event = 'push';
  assert.equal((await plan({ ...f, context: ctx })).eligible, false);
});

test('GitHub merge rejection is reported, and main CI is not dispatched', async () => {
  const f = fixture();
  f.github.rest.pulls.merge = async () => ({ data: { merged: false, message: 'protected branch' } });
  await assert.rejects(publish({ ...f, original, raw: pass }), /protected branch/);
  assert.deepEqual(f.calls.map(x => x[0]), ['comment']);
});
