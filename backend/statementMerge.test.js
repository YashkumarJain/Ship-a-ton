const assert = require("node:assert/strict");
const { parseStatementText, fingerprint } = require("./services/statementParser");
const { saveApprovedTransactions, demoTransactions } = require("./services/statementService");

async function main() {
  const req = { user: { id: "merge-test-user", isDemo: true } };

  const first = parseStatementText(`
09/01/2026 COFFEE SHOP PURCHASE 5.00 995.00
09/02/2026 WHOLE FOODS PURCHASE 40.00 955.00
09/03/2026 PAYROLL DIRECT DEPOSIT 1000.00 1955.00 CR
`);
  assert.equal(first.transactions.length, 3);

  const r1 = await saveApprovedTransactions(req, { approved: true, transactions: first.transactions });
  assert.equal(r1.saved, 3);
  assert.equal(r1.duplicatesSkipped, 0);

  const overlap = parseStatementText(`
09/02/2026 WHOLE FOODS PURCHASE 40.00 955.00
09/03/2026 PAYROLL DIRECT DEPOSIT 1000.00 1955.00 CR
09/04/2026 NETFLIX PURCHASE 20.00 1935.00
`);
  const r2 = await saveApprovedTransactions(req, { approved: true, transactions: overlap.transactions });
  assert.equal(r2.saved, 1);
  assert.equal(r2.duplicatesSkipped, 2);
  assert.equal(demoTransactions(req.user.id).length, 4);

  const categoryA = fingerprint({
    date: "2026-09-05", merchant: "Target", category: "Shopping", amount: 25, type: "expense", sourceOccurrence: 1
  });
  const categoryB = fingerprint({
    date: "2026-09-05", merchant: "Target", category: "Other", amount: 25, type: "expense", sourceOccurrence: 1
  });
  assert.equal(categoryA, categoryB, "category changes must not change transaction identity");

  const duplicateLegit = parseStatementText(`
09/06/2026 COFFEE SHOP PURCHASE 5.00
09/06/2026 COFFEE SHOP PURCHASE 5.00
`);
  assert.equal(duplicateLegit.transactions.length, 2, "legitimate identical rows must both survive parsing");
  assert.notEqual(duplicateLegit.transactions[0].fingerprint, duplicateLegit.transactions[1].fingerprint);

  console.log("statement merge test passed", { first: r1, overlap: r2 });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
