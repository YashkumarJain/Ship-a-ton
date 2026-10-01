const assert = require('node:assert/strict');
const { parseStatementText } = require('./services/statementParser');

const sample = `
Bank statement period 09/01/2026 - 09/30/2026
Date Description Debit Credit Balance
09/02/2026 WHOLE FOODS MARKET 82.45 2,417.55
09/03/2026 NETFLIX.COM 20.00 2,397.55
09/05/2026 PAYROLL DIRECT DEPOSIT 2,500.00 CR 4,897.55
09/07/2026 UBER TRIP 31.25 4,866.30
09/10/2026 APARTMENT RENT 1,500.00 3,366.30
`;

const parsed = parseStatementText(sample);
assert.equal(parsed.transactions.length, 5);
assert.equal(parsed.transactions[0].category, 'Groceries');
assert.equal(parsed.transactions[1].category, 'Subscriptions');
assert.equal(parsed.transactions[2].type, 'income');
assert.equal(parsed.transactions[2].category, 'Income');
assert.equal(parsed.transactions[4].category, 'Rent');
console.log('statement parser test passed', parsed.transactions);
