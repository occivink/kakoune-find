# search for a regex pattern among all opened buffers
# similar to grep.kak

declare-option str toolsclient
declare-option -hidden int find_current_line 0
declare-option -hidden str find_pattern

define-command -params ..1 find %{
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
                    eval -save-regs 'c"' -itersel %{
                        # expand to full lines and yank
                        exec -save-regs '' -draft '<a-x>Hy'
                        # reduce to first character from selection to know the context
                        exec '<a-;>;'
                        set-register c "%val{bufname}:%val{cursor_line}:%val{cursor_column}:"
                        # paste context followed by the selection
                        # also align the selection in case it spans multiple lines
                        exec -buffer *find* 'geo<esc>"cp<a-p><a-s><a-;>&'
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

hook -group find-highlight global WinSetOption filetype=find %{
    add-highlighter group find
    add-highlighter -group find dynregex '%opt{find_pattern}' 0:black,yellow
    add-highlighter -group find regex "^([^\n]*?):(\d+):(\d+)?" 1:cyan,black 2:green,black 3:green,black
    add-highlighter -group find line '%opt{find_current_line}' default+b
    # ensure whitespace is always after
    # kinda hacky
    try %{
        remove-highlighter show_whitespaces
        add-highlighter show_whitespaces
    }
}

hook global WinSetOption filetype=find %{
    hook buffer -group find-hooks NormalKey <ret> find-jump
}

hook -group find-highlight global WinSetOption filetype=(?!find).* %{
    remove-highlighter find
}

hook global WinSetOption filetype=(?!find).* %{
    remove-hooks buffer find-hooks
}

declare-option str jumpclient

define-command -hidden find-jump %{
    eval -collapse-jumps %{
        try %{
            exec -save-regs '' 'xs^([^:]+):(\d+):(\d+)<ret>'
            set-option buffer find_current_line %val{cursor_line}
            eval -try-client %opt{jumpclient} "edit -existing %reg{1} %reg{2} %reg{3}"
            try %{ focus %opt{jumpclient} }
        }
    }
}

define-command find-next-match -docstring 'Jump to the next find match' %{
    eval -collapse-jumps -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}ggl/^[^:]+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}

define-command find-previous-match -docstring 'Jump to the previous find match' %{
    eval -collapse-jumps -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}g<a-/>^[^:]+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}
