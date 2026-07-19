-- Print a read-only TSV inventory of Ghostty windows, tabs, terminals,
-- titles, focus, and working directories.

on run
    set fieldSeparator to character id 9
    set reportText to "window_id" & fieldSeparator & "window_name" & fieldSeparator & "tab_index" & fieldSeparator & "tab_id" & fieldSeparator & "tab_name" & fieldSeparator & "selected" & fieldSeparator & "terminal_id" & fieldSeparator & "terminal_name" & fieldSeparator & "working_directory" & linefeed

    tell application "Ghostty"
        repeat with currentWindow in windows
            set windowId to id of currentWindow as text
            set windowName to name of currentWindow as text

            repeat with currentTab in tabs of currentWindow
                set tabIndex to index of currentTab as text
                set tabId to id of currentTab as text
                set tabName to name of currentTab as text
                set tabSelected to selected of currentTab as text

                repeat with currentTerminal in terminals of currentTab
                    set terminalId to id of currentTerminal as text
                    set terminalName to name of currentTerminal as text
                    set terminalDirectory to working directory of currentTerminal as text
                    set reportText to reportText & windowId & fieldSeparator & windowName & fieldSeparator & tabIndex & fieldSeparator & tabId & fieldSeparator & tabName & fieldSeparator & tabSelected & fieldSeparator & terminalId & fieldSeparator & terminalName & fieldSeparator & terminalDirectory & linefeed
                end repeat
            end repeat
        end repeat
    end tell

    return reportText
end run
