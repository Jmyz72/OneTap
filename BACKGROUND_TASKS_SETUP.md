# Background Tasks Setup for Recurring Transactions

This document explains how to enable background processing for recurring transactions in OneTap.

## Overview

OneTap uses iOS Background Tasks to automatically process recurring transactions even when the app is not running. The app schedules a daily background task to check for and create any due recurring transactions.

## Setup Instructions

### 1. Add Background Modes Capability

1. Open the OneTap project in Xcode
2. Select the OneTap target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Background Modes"
6. Enable "Background processing"

### 2. Register Background Task Identifier

1. In the OneTap target settings, go to the "Info" tab
2. Add a new row under "Permitted background task scheduler identifiers"
3. Set the value to: `xxx.OneTap.processRecurringTransactions`

**OR** if using Info.plist file:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.onetap.processRecurringTransactions</string>
</array>
```

## How It Works

1. **App Launch**: When the app launches, it:
   - Registers the background task handler
   - Processes any due recurring transactions immediately
   - Schedules the next background task (24 hours later)

2. **Background Processing**: iOS will wake the app in the background approximately once per day to:
   - Process recurring transactions that are due
   - Create actual transaction records from recurring templates
   - Update balances accordingly

3. **Task Scheduling**: Each time the background task runs, it automatically schedules the next run.

## Testing Background Tasks

Background tasks don't run in the simulator or during debugging by default. To test:

### Option 1: Xcode Debugger
1. Set a breakpoint in `BackgroundTaskManager.handleRecurringTransactionsProcessing`
2. Run the app
3. In Xcode menu: Debug → Simulate Background Fetch
4. The breakpoint should hit

### Option 2: Command Line
```bash
# Launch the app first, then run:
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.onetap.processRecurringTransactions"]
```

## Limitations

- Background tasks are **not guaranteed** to run at exact times
- iOS controls when background tasks run based on:
  - Device battery level
  - Network conditions
  - App usage patterns
  - System load

- Background tasks may not run if:
  - Low Power Mode is enabled
  - The device is offline (though our task doesn't require network)
  - iOS decides to conserve battery

## Fallback

Even if background processing doesn't run, recurring transactions will still be processed:
1. **On app launch** - Every time the user opens the app
2. **When adding/editing recurring transactions** - The service processes all pending transactions

So background processing is an enhancement, not a critical requirement.

## Code References

- **BackgroundTaskManager**: `OneTap/Core/Services/BackgroundTaskManager.swift`
- **RecurringTransactionService**: `OneTap/Core/Services/RecurringTransactionService.swift`
- **App Setup**: `OneTap/OneTapApp.swift`
