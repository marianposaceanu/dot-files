-- Capture the Ghostty state that is exposed through its AppleScript API.
-- The TSV output optionally includes a temporary full-scrollback file per surface.

use scripting additions

on run arguments
    set separator to character id 9
    set captureScrollback to not (arguments contains "--no-scrollback")
    set reportText to "window_index" & separator & "window_id" & separator & "window_name" & separator & "window_x" & separator & "window_y" & separator & "window_width" & separator & "window_height" & separator & "tab_index" & separator & "tab_id" & separator & "tab_name" & separator & "tab_selected" & separator & "terminal_index" & separator & "terminal_id" & separator & "terminal_name" & separator & "terminal_focused" & separator & "working_directory" & separator & "scrollback_path" & linefeed
    set clipboardWasSaved to false
    set savedClipboard to missing value

    try
        set savedClipboard to the clipboard
        set clipboardWasSaved to true
    end try

    tell application "Ghostty"
        set windowIndex to 0
        repeat with currentWindow in windows
            set windowIndex to windowIndex + 1
            set windowProperties to properties of currentWindow
            set windowId to id of windowProperties as text
            set windowName to name of windowProperties as text
            set windowGeometry to my geometryForWindow(windowIndex)
            set windowX to item 1 of windowGeometry
            set windowY to item 2 of windowGeometry
            set windowWidth to item 3 of windowGeometry
            set windowHeight to item 4 of windowGeometry

            repeat with currentTab in tabs of currentWindow
                set tabProperties to properties of currentTab
                set tabIndex to index of tabProperties as integer
                set tabId to id of tabProperties as text
                set tabName to name of tabProperties as text
                set tabSelected to selected of tabProperties as text
                set focusedTerminalId to ""

                try
                    set focusedTerminalId to id of focused terminal of tabProperties as text
                end try

                set terminalIndex to 0
                repeat with currentTerminal in terminals of currentTab
                    set terminalIndex to terminalIndex + 1
                    set terminalProperties to properties of currentTerminal
                    set terminalId to id of terminalProperties as text
                    set terminalName to name of terminalProperties as text
                    set terminalDirectory to working directory of terminalProperties as text
                    set terminalFocused to (terminalId is focusedTerminalId) as text
                    set scrollbackPath to ""

                    if captureScrollback then
                        try
                            set the clipboard to ""
                            perform action "write_scrollback_file:copy" on currentTerminal

                            try
                                set clipboardValue to the clipboard as text
                                if clipboardValue starts with "/" then set scrollbackPath to clipboardValue
                            end try

                            -- Ghostty currently completes this action synchronously. Keep
                            -- one short retry for compatibility without imposing a one-second
                            -- timeout on every terminal that has no scrollback.
                            if scrollbackPath is "" then
                                delay 0.05
                                try
                                    set clipboardValue to the clipboard as text
                                    if clipboardValue starts with "/" then
                                        set scrollbackPath to clipboardValue
                                    end if
                                end try
                            end if
                        end try
                    end if

                    set reportText to reportText & windowIndex & separator & my cleanField(windowId) & separator & my cleanField(windowName) & separator & windowX & separator & windowY & separator & windowWidth & separator & windowHeight & separator & tabIndex & separator & my cleanField(tabId) & separator & my cleanField(tabName) & separator & tabSelected & separator & terminalIndex & separator & my cleanField(terminalId) & separator & my cleanField(terminalName) & separator & terminalFocused & separator & my cleanField(terminalDirectory) & separator & my cleanField(scrollbackPath) & linefeed
                end repeat
            end repeat
        end repeat
    end tell

    if clipboardWasSaved then
        try
            set the clipboard to savedClipboard
        end try
    end if

    return reportText
end run

on geometryForWindow(windowIndex)
    try
        tell application "System Events"
            tell process "Ghostty"
                set windowPosition to position of window windowIndex
                set windowSize to size of window windowIndex
            end tell
        end tell
        return {item 1 of windowPosition, item 2 of windowPosition, item 1 of windowSize, item 2 of windowSize}
    on error
        return {"", "", "", ""}
    end try
end geometryForWindow

on cleanField(rawValue)
    set cleanedValue to rawValue as text
    set cleanedValue to my replaceText(character id 9, " ", cleanedValue)
    set cleanedValue to my replaceText(return, " ", cleanedValue)
    set cleanedValue to my replaceText(linefeed, " ", cleanedValue)
    return cleanedValue
end cleanField

on replaceText(searchText, replacementText, sourceText)
    set savedDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to searchText
    set sourceItems to text items of sourceText
    set AppleScript's text item delimiters to replacementText
    set replacedText to sourceItems as text
    set AppleScript's text item delimiters to savedDelimiters
    return replacedText
end replaceText
