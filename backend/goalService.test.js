const assert = require('node:assert/strict');
const {
  listGoals,
  resolveProposal,
  applyApprovedProposal,
} = require('./services/goalService');

async function main() {
  const req = { user: { id: 'goal-test-user', isDemo: true } };

  const createProposal = await resolveProposal(req, {
    action: 'create',
    goalName: 'Vacation',
    goalType: 'vacation',
    targetAmount: 3000,
    targetDate: '2027-06-01',
  });
  assert.equal(createProposal.canApply, true);
  await applyApprovedProposal(req, { ...createProposal, approved: true });

  let goals = await listGoals(req);
  assert.equal(goals.length, 1);
  assert.equal(goals[0].targetAmount, 3000);

  const updateProposal = await resolveProposal(req, {
    action: 'update',
    goalNumber: 1,
    goalType: 'vacation',
    targetAmount: 4500,
    targetDate: '2027-07-01',
  });
  assert.ok(updateProposal.goalId);
  await applyApprovedProposal(req, { ...updateProposal, approved: true });

  goals = await listGoals(req);
  assert.equal(goals[0].targetAmount, 4500);
  assert.equal(goals[0].targetDate, '2027-07-01');

  const deleteProposal = await resolveProposal(req, {
    action: 'delete',
    goalName: 'Vacation',
    goalType: 'vacation',
  });
  await applyApprovedProposal(req, { ...deleteProposal, approved: true });
  goals = await listGoals(req);
  assert.equal(goals.length, 0);

  console.log('goal service AI proposal flow test passed');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
