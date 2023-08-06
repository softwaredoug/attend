# Attend

Attend is a deep-work-o-meter. 

[![Bash Tests](https://github.com/softwaredoug/focus/actions/workflows/test.yml/badge.svg)](https://github.com/softwaredoug/focus/actions/workflows/test.yml)

You set an intention for a work session. It tells you how well you stay on task, computing effective minutes on task.

```
$ attend show --goal 4h

Focus since - Thu Jun  1 2023

    Su Mo Tu We Th Fr Sa
May         
28              
Jun
01              ███      
04  █████████▓▓▓▒▒▒▒▒▒   
11     ▓▓▓▓▓▓███▒▒▒▓▓▓▒▒▒
18     ░░░░░░░░░▓▓▓▓▓▓░░░
25     ███      ██████
Jul
01                    ███
02  ▓▓▓▒▒▒▒▒▒      ▓▓▓▓▓▓
09  ███▒▒▒▓▓▓▒▒▒   ░░░░░░
16  ░░░▓▓▓▓▓▓░░░   ███   
23     █████████▓▓▓▒▒▒▒▒▒
30        
Aug
01        ▓▓▓▓▓▓

-------------
Legend (mins)
" " no data
░ 0-60 mins
▒ 60-120 mins
▓ 120-180 mins
█ 180-240 mins
█ > 240 mins
```

"Focused minutes" means more time in one app. The more time you spend in that app, the more the time counts to your effective focus time. See [this graph](https://www.desmos.com/calculator/rdewcjdoab).

## Usage 

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

We stayed on google docs approx 28 minutes of focus time.

### Get a calendar visualization

(as in above)

#### Out of max

```
attend show
```

#### Relative to a goal

```
attend show --goal 4h
```

### Get a detailed output of every work item a date range

```
attend worklog week
```


## Install

```
brew tap softwaredoug/attend
brew install attend
```
