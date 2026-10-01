const assert = require("node:assert/strict");
const { parseStatementText, fingerprint } = require("./services/statementParser");
const { saveApprovedTransactions, previewTransactions, demoTransactions } = require("./services/statementService");

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

  const previewReq = { user: { id: "preview-10-new-4-overlap", isDemo: true } };
  const existingFour = parseStatementText(`
09/01/2026 STORE 01 PURCHASE 11.00
09/02/2026 STORE 02 PURCHASE 12.00
09/03/2026 STORE 03 PURCHASE 13.00
09/04/2026 STORE 04 PURCHASE 14.00
`);
  await saveApprovedTransactions(previewReq, { approved: true, transactions: existingFour.transactions });

  const fourteenRows = parseStatementText(`
09/01/2026 STORE 01 PURCHASE 11.00
09/02/2026 STORE 02 PURCHASE 12.00
09/03/2026 STORE 03 PURCHASE 13.00
09/04/2026 STORE 04 PURCHASE 14.00
09/05/2026 STORE 05 PURCHASE 15.00
09/06/2026 STORE 06 PURCHASE 16.00
09/07/2026 STORE 07 PURCHASE 17.00
09/08/2026 STORE 08 PURCHASE 18.00
09/09/2026 STORE 09 PURCHASE 19.00
09/10/2026 STORE 10 PURCHASE 20.00
09/11/2026 STORE 11 PURCHASE 21.00
09/12/2026 STORE 12 PURCHASE 22.00
09/13/2026 STORE 13 PURCHASE 23.00
09/14/2026 STORE 14 PURCHASE 24.00
`);
  const preview = await previewTransactions(previewReq, fourteenRows.transactions);
  assert.equal(preview.saved, 10, "preview should show 10 new transactions");
  assert.equal(preview.duplicatesSkipped, 4, "preview should show 4 overlaps");

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

  console.log("statement merge test passed", { first: r1, overlap: r2, preview });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
