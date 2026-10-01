const { AsyncLocalStorage } = require("node:async_hooks");
const defaultFinancialData = require("./financialData");

const storage = new AsyncLocalStorage();

function currentData() {
  return storage.getStore()?.financialData || defaultFinancialData;
}

const financialData = new Proxy({}, {
  get(_target, property) {
    return currentData()[property];
  },
  set() {
    throw new Error("financialData is read-only inside the financial context");
  }
});

function withFinancialData(data, fn) {
  return storage.run({ financialData: data }, fn);
}

module.exports = {
  financialData,
  withFinancialData,
  defaultFinancialData
};
