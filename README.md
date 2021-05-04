# Zig-to-do-list
The Zig to-do list. https://xkcd.com/1319/

## Current Usage
```
$todo adding tasks is easy
Added task.
❌ adding tasks is easy

$todo you can have due dates ; jan 24
Added task.
❌ you can have due dates 📅 January 24, 2021

$todo -l
1. ❌ adding tasks is easy
2. ❌ you can have due dates 📅 January 24, 2021

$todo -r 2
Removed task
❌ you can have due dates 📅 January 24, 2021

$todo if you don't specify a number, it deletes the latest task
Added task.
❌ if you don't specify a number, it deletes the latest task

$todo -l
1. ❌ adding tasks is easy
2. ❌ if you don't specify a number, it deletes the latest task

$todo -r
Removed task
❌ adding tasks is easy

$todo aint that beautiful?
Added task.
❌ aint that beautiful?

$todo -c
✅ if you don't specify a number, it deletes the latest task

$todo -l
1. ❌ aint that beautiful?
2. ✅ if you don't specify a number, it deletes the latest task
```

Using Zig version: 0.8.0-dev.1981+fbda9991f
