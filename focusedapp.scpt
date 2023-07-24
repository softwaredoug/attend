-- Get the frontmost application name

tell application "System Events"
    set frontAppProcess to first process where frontmost is true
    set appName to name of frontAppProcess

end tell

tell frontAppProcess
    set window_name to ""
    if count of windows > 0 then
       set window_name to name of front window
    end if
end tell

-- Return: App name || window name
return appName & " || " & window_name

end run
