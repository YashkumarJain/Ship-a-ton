const financialToolDefinitions = [

  // =========================================================
  // 1. GET TRANSACTIONS
  // =========================================================

  {
    type: "function",
    name: "get_transactions",

    description:
      "Retrieve the user's actual transactions using optional filters. Use this when you need transaction-level details such as merchants, dates, individual purchases, specific categories, or purchases above or below an amount.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string",
          description:
            "Start date in YYYY-MM-DD format."
        },

        endDate: {
          type: "string",
          description:
            "End date in YYYY-MM-DD format."
        },

        category: {
          type: "string",
          description:
            "Optional spending category such as Dining, Shopping, Groceries, Travel, Rent, Transport, or Subscriptions."
        },

        type: {
          type: "string",
          enum: ["income", "expense"],
          description:
            "Filter for income or expense transactions."
        },

        merchant: {
          type: "string",
          description:
            "Optional merchant name or partial merchant name."
        },

        minAmount: {
          type: "number",
          description:
            "Return transactions with at least this amount."
        },

        maxAmount: {
          type: "number",
          description:
            "Return transactions with no more than this amount."
        }
      },

      additionalProperties: false
    }
  },


  // =========================================================
  // 2. SPENDING BY CATEGORY
  // =========================================================

  {
    type: "function",
    name: "get_spending_by_category",

    description:
      "Calculate expense totals grouped by category for a chosen period. Use this to understand where money went, identify major spending categories, or create category charts.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string",
          description:
            "Start date in YYYY-MM-DD format."
        },

        endDate: {
          type: "string",
          description:
            "End date in YYYY-MM-DD format."
        }
      },

      additionalProperties: false
    }
  },


  // =========================================================
  // 3. SPENDING FOR PERIOD
  // =========================================================

  {
    type: "function",
    name: "get_spending_for_period",

    description:
      "Calculate total spending and transaction count for a chosen period. Use this when the user asks how much they spent during a month, week, or custom date range.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string",
          description:
            "Start date in YYYY-MM-DD format."
        },

        endDate: {
          type: "string",
          description:
            "End date in YYYY-MM-DD format."
        }
      },

      additionalProperties: false
    }
  },


  // =========================================================
  // 4. COMPARE PERIODS
  // =========================================================

  {
    type: "function",
    name: "compare_periods",

    description:
      "Compare total spending and category-level spending between two periods. Use this for questions such as this month versus last month, July versus August, or one time period versus another.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        periodA: {
          type: "object",

          properties: {

            startDate: {
              type: "string"
            },

            endDate: {
              type: "string"
            }
          },

          required: [
            "startDate",
            "endDate"
          ],

          additionalProperties: false
        },


        periodB: {
          type: "object",

          properties: {

            startDate: {
              type: "string"
            },

            endDate: {
              type: "string"
            }
          },

          required: [
            "startDate",
            "endDate"
          ],

          additionalProperties: false
        }
      },

      required: [
        "periodA",
        "periodB"
      ],

      additionalProperties: false
    }
  },


  // =========================================================
  // 5. FIND LARGEST TRANSACTIONS
  // =========================================================

  {
    type: "function",
    name: "find_largest_transactions",

    description:
      "Find the user's largest individual expenses and calculate how much of spending is concentrated in those purchases. Use this to investigate unusually large purchases or whether a spending increase came from a few big transactions.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string"
        },

        endDate: {
          type: "string"
        },

        category: {
          type: "string"
        },

        merchant: {
          type: "string"
        },

        minAmount: {
          type: "number"
        },

        maxAmount: {
          type: "number"
        },

        limit: {
          type: "integer",
          description:
            "Maximum number of transactions to return."
        },

        excludeCategories: {
          type: "array",

          items: {
            type: "string"
          },

          description:
            "Categories to ignore, such as Rent."
        }
      },

      additionalProperties: false
    }
  },


  // =========================================================
  // 6. FIND RECURRING EXPENSES
  // =========================================================

  {
    type: "function",
    name: "find_recurring_expenses",

    description:
      "Detect predictable recurring charges by examining repeated merchant transactions across multiple months. Use this for subscriptions, rent, recurring bills, or committed monthly expenses.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string"
        },

        endDate: {
          type: "string"
        },

        minOccurrences: {
          type: "integer",
          description:
            "Minimum number of recurring appearances required."
        },

        amountTolerance: {
          type: "number",
          description:
            "Allowed variation in recurring charge amounts, expressed as a decimal such as 0.10 for 10 percent."
        }
      },

      additionalProperties: false
    }
  },


  // =========================================================
  // 7. DETECT SPENDING CHANGES
  // =========================================================

  {
    type: "function",
    name: "detect_spending_changes",

    description:
      "Analyze how spending changed between two periods and identify significant increases, decreases, new categories, and the categories contributing most to the overall change. Use this when the user asks why spending increased or what has changed lately.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        previousPeriod: {
          type: "object",

          properties: {

            startDate: {
              type: "string"
            },

            endDate: {
              type: "string"
            }
          },

          required: [
            "startDate",
            "endDate"
          ],

          additionalProperties: false
        },


        currentPeriod: {
          type: "object",

          properties: {

            startDate: {
              type: "string"
            },

            endDate: {
              type: "string"
            }
          },

          required: [
            "startDate",
            "endDate"
          ],

          additionalProperties: false
        },


        minDollarChange: {
          type: "number",
          description:
            "Optional minimum dollar change considered significant."
        },

        minPercentChange: {
          type: "number",
          description:
            "Optional minimum percentage change considered significant."
        }
      },

      required: [
        "previousPeriod",
        "currentPeriod"
      ],

      additionalProperties: false
    }
  },


  // =========================================================
  // 8. CALCULATE BUDGET REMAINING
  // =========================================================

  {
    type: "function",
    name: "calculate_budget_remaining",

    description:
      "Calculate how much of the user's budget remains after recorded spending and optionally known upcoming bills. Use this for questions about remaining budget or how much is still available to spend.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string"
        },

        endDate: {
          type: "string"
        },

        budget: {
          type: "number",
          description:
            "Optional custom budget. If omitted, use the user's stored monthly budget."
        },

        includeUpcomingBills: {
          type: "boolean",
          description:
            "Whether known upcoming bills should reduce the remaining amount."
        }
      },

      additionalProperties: false
    }
  },


  // =========================================================
  // 9. PROJECT MONTHLY SPENDING
  // =========================================================

  {
    type: "function",
    name: "project_monthly_spending",

    description:
      "Forecast month-end spending using spending observed so far, recurring expenses, variable spending pace, and known future bills. Use this for questions about whether the user is on pace to exceed their budget or how much they may spend by month end.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string",
          description:
            "Beginning of the month in YYYY-MM-DD format."
        },

        endDate: {
          type: "string",
          description:
            "End of the month in YYYY-MM-DD format."
        },

        asOfDate: {
          type: "string",
          description:
            "Date through which recorded spending should be treated as actual."
        },

        budget: {
          type: "number"
        }
      },

      required: [
        "startDate",
        "endDate",
        "asOfDate"
      ],

      additionalProperties: false
    }
  },


  // =========================================================
  // 10. CALCULATE SAVINGS CAPACITY
  // =========================================================

  {
    type: "function",
    name: "calculate_savings_capacity",

    description:
      "Estimate how much the user may realistically be able to save based on income and projected month-end expenses. Use this when the user asks how much they can save or whether there is positive savings capacity.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string"
        },

        endDate: {
          type: "string"
        },

        asOfDate: {
          type: "string"
        },

        reserveAmount: {
          type: "number",
          description:
            "Optional amount of cash the user wants to keep untouched."
        }
      },

      required: [
        "startDate",
        "endDate",
        "asOfDate"
      ],

      additionalProperties: false
    }
  },


  // =========================================================
  // 11. SIMULATE SAVINGS GOAL
  // =========================================================

  {
    type: "function",
    name: "simulate_savings_goal",

    description:
      "Simulate whether the user can reach a target savings balance within a number of months. Calculates required monthly savings, likely shortfall, and how much monthly cash flow would need to improve. Use this for future savings goals, trips, emergency funds, or what-if planning.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        targetSavingsBalance: {
          type: "number",
          description:
            "Desired total savings balance at the deadline."
        },

        months: {
          type: "integer",
          description:
            "Number of months available to reach the goal."
        },

        startDate: {
          type: "string"
        },

        endDate: {
          type: "string"
        },

        asOfDate: {
          type: "string"
        },

        currentSavings: {
          type: "number",
          description:
            "Optional current savings balance. If omitted, use the stored user balance."
        }
      },

      required: [
        "targetSavingsBalance",
        "months",
        "startDate",
        "endDate",
        "asOfDate"
      ],

      additionalProperties: false
    }
  },


  // =========================================================
  // 12. CALCULATE CASH FLOW
  // =========================================================

  {
    type: "function",
    name: "calculate_cash_flow",

    description:
      "Calculate income, expenses, known upcoming bills, and net cash flow for a chosen period. Use this when the user asks whether they are spending more than they earn, how much money is left after expenses, or what their overall cash flow looks like.",

    strict: false,

    parameters: {
      type: "object",

      properties: {

        startDate: {
          type: "string"
        },

        endDate: {
          type: "string"
        },

        includeUpcomingBills: {
          type: "boolean"
        }
      },

      required: [
        "startDate",
        "endDate"
      ],

      additionalProperties: false
    }
  }

];


module.exports = {
  financialToolDefinitions
};