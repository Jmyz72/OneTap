OneTap is a personal finance app designed for fast, low-effort tracking.

CORE IDEA
- One real-world payment = one record
- The app should feel effortless and opinionated
- Details are optional, not forced
- Default behavior should “just work” without setup

TRANSACTIONS
- Each transaction represents a single payment
- Shown as one row in the main list
- Title is required and shown prominently
- Amount and date are required
- Transactions can be:
  - Expense
  - Income
  - Transfer (handled internally, not as a separate concept)

SPLIT TRANSACTIONS
- A transaction may optionally contain multiple items
- Example: one breakfast payment split into food + drink
- Items are hidden by default and shown only when viewing details
- If no items exist, the transaction itself acts as a single item
- Summaries use items if they exist, otherwise the transaction

ACCOUNTS
- The app supports multiple accounts
- Examples: Cash, Bank, Credit Card, Investment
- Every transaction belongs to one account
- Transfers move money between two accounts
- Account balances update automatically
- Accounts can be created, renamed, hidden, but not over-configured

CATEGORIES
- Categories are required for transactions
- Categories are user-editable
- Users can:
  - Add new categories
  - Rename categories
  - Reorder categories
  - Hide unused categories
- Categories are used for summaries and charts
- Categories should be simple and flexible

MERCHANTS
- Merchant is optional for a transaction
- Merchant is free-text, not forced
- Users can modify merchant names later
- Merchant input should support reuse or suggestions
- Merchant is used for clarity, not calculations

ADDING TRANSACTIONS
- Quick add should require minimal input
- Default flow:
  - Choose category
  - Enter amount
  - Save
- Title, account, and date should auto-fill intelligently
- Advanced details are optional and hidden unless expanded

SUMMARIES


SETTINGS PHILOSOPHY

