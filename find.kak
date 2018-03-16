# search for a regex pattern among all opened buffers
# similar to grep.kak

declare-option str toolsclient
declare-option -hidden int find_current_line 0
declare-option -hidden str find_pattern

define-command -params ..1 -docstring "
find [<pattern>]: search for a pattern in all buffers
If <pattern> is not specified, the main selection is used
" find %{
    eval -no-hooks -save-regs '/' %{
        try %{
            %sh{ [ -z "$1" ] && echo fail }
            set-register / %arg{1}
        } catch %{
            exec -save-regs '' '*'
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
                    exec -buffer *find* 'geo<esc>"cp<a-p>'
                }
            }
        }
        eval -try-client %opt{toolsclient} %{
            buffer *find*
            # delete empty line at the top
            exec d
            set-option buffer find_pattern "%reg{/}"
            set-option buffer find_current_line 0

            add-highlighter buffer dynregex '%opt{find_pattern}' 0:black,yellow
            add-highlighter buffer regex "^([^\n]+):(\d+):(\d+):" 1:cyan,black 2:green,black 3:green,black
            add-highlighter buffer line '%opt{find_current_line}' default+b
            map buffer normal <ret> :find-jump<ret>
        }
    }
}

declare-option str jumpclient

define-command -hidden find-apply-impl -params 3 %{
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
            set-register s "%reg{s}o"
        } catch %{
            set-register i "%reg{i}o"
        }
    }
}
define-command -hidden find-apply-force-impl -params 3 %{
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
find-apply-changes [-force]: apply changes from the current buffer to their file
If -force is specified, changes will also be applied to files that do not have a buffer
" %{
    eval -save-regs 'sif' %{
        set-register s ""
        set-register i ""
        set-register f ""
        eval -save-regs 'c' -draft %{
            # select all lines that match the *find* pattern
            exec '%s^([^\n]+):(\d+):\d+:([^\n]*)$<ret>'
            set-register c %sh{ [ "$1" = "-force" ] && c=find-apply-force-impl || c=find-apply-impl; printf $c }
            eval -itersel %{
                try %{
                    %reg{c} %reg{1} %reg{2} %reg{3}
                } catch %{
                    set-register f "%reg{f}o"
                }
            }
        }
        echo -markup %sh{
            printf "\"{Information}"
            s=${#kak_reg_s}
            [ $s -ne 1 ] && p=s
            printf "%i change%s applied" "$s" "$p"
            i=${#kak_reg_i}
            [ $i -gt 0 ] && printf ", %i ignored" "$i"
            f=${#kak_reg_f}
            [ $f -gt 0 ] && printf ", %i failed" "$f"
            printf "\""
        }
    }
}

define-command -hidden find-jump %{
    eval %{
        try %{
            exec -save-regs '' '<a-x>s^([^\n]+):(\d+):(\d+):<ret>'
            set-option buffer find_current_line %val{cursor_line}
            eval -try-client %opt{jumpclient} "edit -existing %reg{1} %reg{2} %reg{3}"
            try %{ focus %opt{jumpclient} }
        }
    }
}

define-command find-next-match -docstring 'Jump to the next find match' %{
    eval -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}ggl/^[^\n]+:\d+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}

define-command find-previous-match -docstring 'Jump to the previous find match' %{
    eval -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}g<a-/>^[^\n]+:\d+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}
