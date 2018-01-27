# search for a regex pattern among all opened buffers
# similar to grep.kak

declare-option str toolsclient
declare-option -hidden int find_current_line 0
declare-option -hidden str find_pattern

declare-option -hidden str find_application_successes
declare-option -hidden str find_application_ignored
declare-option -hidden str find_application_failures

define-command -params ..1 -docstring "
find [<pattern>]: search for a pattern in all buffers
" find %{
    eval -no-hooks -save-regs '/' %{
        eval -save-regs '' -draft %{
            %sh{
                if [ -n "$1" ]; then
                    echo "set-register / %arg{1}"
                else
                    echo "exec -save-regs '' <a-*>"
                fi
            }
            try %{ delete-buffer *find* }
            eval -buffer * %{
                # create find buffer after we start iterating so as not to include it
                eval -draft %{ edit -scratch *find* }
                try %{
                    exec '%s<ret>'
                    # merge selections that are on the same line
                    exec '<a-l>'
                    exec '<a-;>;'
                    eval -save-regs 'c"' -itersel %{
                        set-register c "%val{bufname}:%val{cursor_line}:%val{cursor_column}:"
                        # expand to full line and yank
                        exec -save-regs '' '<a-x>Hy'
                        # paste context followed by the selection
                        # also align the selection in case it spans multiple lines
                        exec -buffer *find* 'geo<esc>"cp<a-p>'
                    }
                }
            }
            # delete empty line at the top
            exec -buffer *find* d
        }
        eval -try-client %opt{toolsclient} %{
            buffer *find*
            set-option buffer find_pattern "%reg{/}"
            set-option buffer filetype find
            set-option buffer find_current_line 0
        }
    }
}

hook global BufSetOption filetype=find %{
    add-highlighter buffer group find
    add-highlighter buffer/find dynregex '%opt{find_pattern}' 0:black,yellow
    add-highlighter buffer/find regex "^([^\n]+):(\d+):(\d+):" 1:cyan,black 2:green,black 3:green,black
    add-highlighter buffer/find line '%opt{find_current_line}' default+b
    map buffer normal <ret> :find-jump<ret>
}

hook global BufSetOption filetype=(?!find).* %{
    remove-highlighter buffer/find
    unmap buffer normal <ret> :find-jump<ret>
}

declare-option str jumpclient

define-command find-apply-impl -params 3 %{
    eval -buffer %arg{1} %{
        # only change if the content is different
        # to avoid putting any noop in the undo stack
        try %{
            # go to the target line and select up to \n
            exec "%arg{2}g<a-x>H"
            # make sure the replacement is not a noop
            set-register / "\A\Q%arg{3}\E\z"
            exec "<a-K><c-r>/<ret>"
            # replace
            set-register '"' %arg{3}
            exec R
            set-option -add buffer=*find* find_application_successes o
        } catch %{
            set-option -add buffer=*find* find_application_ignored o
        }
    }
}
define-command find-apply-force-impl -params 3 %{
    try %{
        find-apply-impl %arg{1} %arg{2} %arg{3}
    } catch %{
        # the buffer wasn't open: try editing it
        # if this fails there is nothing we can do
        eval -draft "edit -existing %arg{1}"
        find-apply-impl %arg{1} %arg{2} %arg{3}
        eval -buffer %arg{1} "write; delete-buffer"
    }
}

define-command find-apply-changes -params ..1 -docstring "
find-apply-changes [-force]: apply changes from *find* to their file
If -force is specified, changes will also be applied to files withtout a buffer
" %{
    unset-option buffer find_application_successes
    unset-option buffer find_application_ignored
    unset-option buffer find_application_failures
    eval -save-regs 'c' -draft %{
        # select all lines that match the *find* pattern
        exec '%s^([^\n]+):(\d+):\d+:([^\n]*)$<ret>'
        set-register c %sh{ [ "$1" = "-force" ] && c=find-apply-force-impl || c=find-apply-impl; printf $c }
        eval -itersel %{
            try %{
                %reg{c} %reg{1} %reg{2} %reg{3}
            } catch %{
                set-option -add buffer find_application_failures o
            }
        }
    }
    echo -markup %sh{
        printf "\"{Information}"
        s=${#kak_opt_find_application_successes}
        [ $s -ne 1 ] && p=s
        printf "%i change%s applied" "$s" "$w"
        i=${#kak_opt_find_application_ignored}
        [ $i -gt 0 ] && printf ", %i ignored" "$i"
        f=${#kak_opt_find_application_failures}
        [ $f -gt 0 ] && printf ", %i failed" "$f"
        printf "\""
    }
}

define-command -hidden find-jump %{
    eval -collapse-jumps %{
        try %{
            exec -save-regs '' '<a-x>s^([^\n]+):(\d+):(\d+):<ret>'
            set-option buffer find_current_line %val{cursor_line}
            eval -try-client %opt{jumpclient} "edit -existing %reg{1} %reg{2} %reg{3}"
            try %{ focus %opt{jumpclient} }
        }
    }
}

define-command find-next-match -docstring 'Jump to the next find match' %{
    eval -collapse-jumps -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}ggl/^[^\n]+:\d+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}

define-command find-previous-match -docstring 'Jump to the previous find match' %{
    eval -collapse-jumps -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}g<a-/>^[^\n]+:\d+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}
