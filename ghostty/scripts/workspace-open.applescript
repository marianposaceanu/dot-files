-- Ensure the usual Ghostty project workspace exists without disturbing
-- existing tabs. Existing tabs are claimed by working directory; only
-- missing tabs are created and split.

on run argv
    set previewOnly to (argv contains "--dry-run")
    set homePath to "/Users/marian/"
    set workspaceSpecs to {¬
        {"fws-docs", homePath & "work/fws-docs", 2}, ¬
        {"fws-llms", homePath & "work/fws-llms-tester", 1}, ¬
        {"jira", homePath & "Desktop/JIRA", 2}, ¬
        {"ark-shell", homePath & "work/playground/ark-mp-com", 2}, ¬
        {"cronos-main", homePath & "work/playground/cronos_dawn_opt", 2}, ¬
        {"cronos-current", homePath & "work/playground/cronos_dawn_opt", 1}, ¬
        {"ark-codex", homePath & "work/playground/ark-mp-com", 2}}

    set reportText to ""
    set claimedTabIds to {}
    set fieldSeparator to character id 9

    tell application "Ghostty"
        set originalTerminal to missing value
        if (count of windows) > 0 then
            set originalWindow to front window
            if originalWindow is not missing value then
                set originalTab to selected tab of originalWindow
                if originalTab is not missing value then
                    set originalTerminal to focused terminal of originalTab
                end if
            end if
        end if

        repeat with workspaceSpec in workspaceSpecs
            set specValues to contents of workspaceSpec
            set workspaceLabel to item 1 of specValues
            set workspacePath to item 2 of specValues
            set desiredTerminalCount to item 3 of specValues
            set matchingTab to missing value

            repeat with candidateWindow in windows
                repeat with candidateTab in tabs of candidateWindow
                    set candidateTabId to id of candidateTab as text
                    if claimedTabIds does not contain candidateTabId then
                        repeat with candidateTerminal in terminals of candidateTab
                            if (working directory of candidateTerminal as text) is workspacePath then
                                set matchingTab to candidateTab
                                exit repeat
                            end if
                        end repeat
                    end if
                    if matchingTab is not missing value then exit repeat
                end repeat
                if matchingTab is not missing value then exit repeat
            end repeat

            if matchingTab is not missing value then
                set end of claimedTabIds to (id of matchingTab as text)
                set actualTerminalCount to count of terminals of matchingTab
                set reportText to reportText & "keep" & fieldSeparator & workspaceLabel & fieldSeparator & workspacePath & fieldSeparator & actualTerminalCount & linefeed
            else if previewOnly then
                set reportText to reportText & "missing" & fieldSeparator & workspaceLabel & fieldSeparator & workspacePath & fieldSeparator & desiredTerminalCount & linefeed
            else
                set surfaceConfig to new surface configuration
                set initial working directory of surfaceConfig to workspacePath

                if (count of windows) is 0 then
                    set createdWindow to new window with configuration surfaceConfig
                    set createdTab to selected tab of createdWindow
                else
                    set createdTab to new tab in front window with configuration surfaceConfig
                end if

                set anchorTerminal to focused terminal of createdTab
                perform action ("set_tab_title:" & workspaceLabel) on anchorTerminal

                if desiredTerminalCount > 1 then
                    repeat with terminalIndex from 2 to desiredTerminalCount
                        set anchorTerminal to split anchorTerminal direction right with configuration surfaceConfig
                    end repeat
                end if

                set end of claimedTabIds to (id of createdTab as text)
                set reportText to reportText & "created" & fieldSeparator & workspaceLabel & fieldSeparator & workspacePath & fieldSeparator & desiredTerminalCount & linefeed
            end if
        end repeat

        if not previewOnly and originalTerminal is not missing value then
            focus originalTerminal
        end if
    end tell

    return reportText
end run
