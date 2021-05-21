# Zig-to-do-list
The Zig to-do list. https://xkcd.com/1319/

## .todo format (subject to change once undo is added)
line 1: utc \
line 2: daylight \
line 3..: tasks \

`utc` is a signed integer.
`daylight` can either be 0 or 1.

A task is: content\x01unix time\x01completed

`content` is a string. `\x01` is byte code, used to separate the parts of a task. `unix time` is either null, or it is the due date, represented by the seconds since 1970 January 1st UTC+0. `completed` can either be 0 or 1.

## Current Usage
![Screenshot 1](img/First.jpg)
![Screenshot 2](img/Second.jpg)

Using Zig version: 0.8.0-dev.1981+fbda9991f
