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

----------------------------------------
Work session:
  Unnamed Session
----
You started working at 2023-01-01T00:00
Session lasted mins: 50.02
Idle mins: 0.00
 🎉🎉🎉🎉🎉🎉🎉🎉🎉
 New high perc. for > 5 min session! -- 80.00%
----
Effective focus %: 80.00
Total effective mins: 40.01
Num task switches: 0
----
Most focused app: Google Chrome || docs.google.com
Focused mins: 28.00
---------------------------------------
```

## Install

```
brew tap softwaredoug/attend
brew install attend
```
