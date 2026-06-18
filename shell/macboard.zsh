# macboard — PC-style word navigation at the zsh prompt.
#
# Terminals (Ghostty, iTerm2, Terminal.app, the VS Code terminal, tmux) send xterm
# CSI sequences for Ctrl+arrows, but zsh has no default binding for them on macOS.
# macboard's installer also disables the macOS "Move left/right a space" shortcut so
# these keys reach the terminal (instead of switching Spaces) — this file is what then
# turns them into word motions. Terminal-agnostic.
#
# Two sequence families are bound for each motion:
#   - Ctrl  variants (^[[1;5C/D, ^[[3;5~, ^H) — raw Ctrl+arrow, where it reaches zsh.
#   - Option variants (^[[1;3C/D, ^[[3;3~, ^[^?) — emitted when macboard's Karabiner
#     nav rules translate Ctrl+arrow -> Option+arrow inside the VS Code family (e.g. its
#     integrated terminal); system terminals stay raw and use the Ctrl variants above.
#     Binding both keeps word-jump working whichever form zsh receives.
#
# Enable by sourcing from your ~/.zshrc:
#     source /path/to/macboard/shell/macboard.zsh

# --- Ctrl variants (raw Ctrl+arrow reaching zsh) ---
bindkey '^[[1;5C' forward-word          # Ctrl+Right     -> forward one word
bindkey '^[[1;5D' backward-word         # Ctrl+Left      -> back one word
bindkey '^H'      backward-kill-word    # Ctrl+Backspace -> delete word left
bindkey '^[[3;5~' kill-word             # Ctrl+Delete    -> delete word right

# --- Option variants (Ctrl+arrow remapped to Option+arrow by Karabiner) ---
bindkey '^[[1;3C' forward-word          # Option+Right     -> forward one word
bindkey '^[[1;3D' backward-word         # Option+Left      -> back one word
bindkey '^[^?'    backward-kill-word    # Option+Backspace -> delete word left
bindkey '^[[3;3~' kill-word             # Option+Delete    -> delete word right

# --- Home / End (PC-style line motion; macOS zsh leaves these unbound -> terminal bell) ---
# Bind every sequence variant terminals send (xterm, application-cursor, vt220) so Home/End
# jump to line start/end at the prompt the way they do on Linux.
bindkey '^[[H'  beginning-of-line       # Home (xterm)
bindkey '^[[F'  end-of-line             # End  (xterm)
bindkey '^[OH'  beginning-of-line       # Home (application cursor mode)
bindkey '^[OF'  end-of-line             # End  (application cursor mode)
bindkey '^[[1~' beginning-of-line       # Home (vt220)
bindkey '^[[4~' end-of-line             # End  (vt220)
