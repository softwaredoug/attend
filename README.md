# Attend

[![Bash Tests](https://github.com/softwaredoug/focus/actions/workflows/test.yml/badge.svg)](https://github.com/softwaredoug/focus/actions/workflows/test.yml)

Scores your work sessions based on how little you switch the main focus in OSX. 

More time in one app == higher score.
(also plays a bell anytime you switch your OSX task to remind you)

```
attend start "Review the document"
```

Work work work... sometime later

```
attend stop

Work session done!
   Review the document
----------------------------------------
...All scores in effective seconds...
   the more time you spend on a task, the more the seconds accumulate!...
----------------------------------------
You started working at 2023-07-25T16:49:04
Work session length: 15120 seconds
----
Average focus score: 1500.49887665797257113314
Max focus score: 3000.99775331594514226628
Most focused app: Google Chrome || https://docs.google.com
Num task switches: 45
Total idle time: 12
----
🎉🎉🎉🎉🎉🎉🎉🎉🎉
New high max score! -- 3000.99775331594514226628
```

## Install

```
brew tap softwaredoug/attend
brew install attend
```
