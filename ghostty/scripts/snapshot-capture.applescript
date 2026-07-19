-- Capture the Ghostty state that is exposed through its AppleScript API.
-- The TSV output includes a temporary full-scrollback file for every surface.

use scripting additions

on run
    set separator to character id 9
    set reportText to "window_index" & separator & "window_id" & separator & "window_name" & separator & "tab_index" & separator & "tab_id" & separator & "tab_name" & separator & "tab_selected" & separator & "terminal_index" & separator & "terminal_id" & separator & "terminal_name" & separator & "terminal_focused" & separator & "working_directory" & separator & "scrollback_path" & linefeed
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
            set windowId to id of currentWindow as text
            set windowName to name of currentWindow as text

            repeat with currentTab in tabs of currentWindow
                set tabIndex to index of currentTab as integer
                set tabId to id of currentTab as text
                set tabName to name of currentTab as text
                set tabSelected to selected of currentTab as text
                set focusedTerminalId to ""

                try
                    set focusedTerminalId to id of focused terminal of currentTab as text
                end try

                set terminalIndex to 0
                repeat with currentTerminal in terminals of currentTab
                    set terminalIndex to terminalIndex + 1
                    set terminalId to id of currentTerminal as text
                    set terminalName to name of currentTerminal as text
                    set terminalDirectory to working directory of currentTerminal as text
                    set terminalFocused to (terminalId is focusedTerminalId) as text
                    set scrollbackPath to ""

                    try
                        set the clipboard to ""
                        perform action "write_scrollback_file:copy" on currentTerminal

                        repeat with attemptIndex from 1 to 20
                            delay 0.05
                            try
                                set clipboardValue to the clipboard as text
                                if clipboardValue starts with "/" then
                                    set scrollbackPath to clipboardValue
                                    exit repeat
                                end if
                            end try
                        end repeat
                    end try

                    set reportText to reportText & windowIndex & separator & my cleanField(windowId) & separator & my cleanField(windowName) & separator & tabIndex & separator & my cleanField(tabId) & separator & my cleanField(tabName) & separator & tabSelected & separator & terminalIndex & separator & my cleanField(terminalId) & separator & my cleanField(terminalName) & separator & terminalFocused & separator & my cleanField(terminalDirectory) & separator & my cleanField(scrollbackPath) & linefeed
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
