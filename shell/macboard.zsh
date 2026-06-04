# macboard — PC-style word navigation at the zsh prompt.
#
# Terminals (Ghostty, iTerm2, Terminal.app, the VS Code terminal, tmux) send xterm
# CSI sequences for Ctrl+arrows, but zsh has no default binding for them on macOS.
# macboard's installer also disables the macOS "Move left/right a space" shortcut so
# these keys reach the terminal (instead of switching Spaces) — this file is what then
# turns them into word motions. Terminal-agnostic.
#
# Enable by sourcing from your ~/.zshrc:
#     source /path/to/macboard/shell/macboard.zsh
bindkey '^[[1;5C' forward-word          # Ctrl+Right     -> forward one word
bindkey '^[[1;5D' backward-word         # Ctrl+Left      -> back one word
bindkey '^H'      backward-kill-word    # Ctrl+Backspace -> delete word left
bindkey '^[[3;5~' kill-word             # Ctrl+Delete    -> delete word right
