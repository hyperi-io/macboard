{
  //--------------------//
  // BUNDLE IDENTIFIERS //
  //--------------------//

  // bundle identifiers for hypervisor applications
  hypervisors: [
    // Oracle VirtualBox
    '^org\\.virtualbox\\.app\\.VirtualBoxVM$',
    // Parallels
    '^com\\.parallels\\.desktop\\.console$',
    // VMWare Fusion
    '^org\\.vmware\\.fusion$',
  ],

  // bundle identifiers for IDE applications
  ides: [
    // GNU Emacs (GUI)
    '^org\\.gnu\\.emacs$',
    '^org\\.gnu\\.Emacs$',
    // JetBrains tools
    '^com\\.jetbrains',
    // Microsoft VSCode (including Insiders)
    '^com\\.microsoft\\.VSCode',
    // VSCodium - Open Source VSCode
    '^com\\.vscodium$',
    // Sublime Text
    '^com\\.sublimetext\\.3$',
    // Kitty
    '^net\\.kovidgoyal\\.kitty$',
    // Beyond Compare 4 & 5
    '^com\\.ScooterSoftware',
    // Zed
    '^dev\\.zed\\.Zed$',
  ],

  // bundle identifiers for the VS Code family (editors that host the Claude Code panel).
  // Narrower than `ides` ON PURPOSE: these get Windows clipboard keys (incl. Ctrl+C=copy),
  // which would be destructive for the other IDEs -- Emacs (Ctrl+C is its prefix key) and
  // Kitty (a terminal needing Ctrl+C=interrupt) -- so they are deliberately NOT included.
  vscodeFamily: [
    // Microsoft VS Code + VS Code Insiders (prefix match)
    '^com\\.microsoft\\.VSCode',
    // VSCodium
    '^com\\.vscodium$',
    // Cursor (todesktop-packaged; published bundle id)
    '^com\\.todesktop\\.230313mzl4w4u92$',
  ],

  // bundle identifiers for remote desktop applications
  remoteDesktops: [
    // Citrix XenAppViewer
    '^com\\.citrix\\.XenAppViewer$',
    // Microsoft Remote Desktop Connection
    '^com\\.microsoft\\.rdc\\.macos$',
  ],

  // bundle identifiers for terminal emulator applications
  terminalEmulators: [
    // Alacritty (New)
    '^com\\.alacritty$',
    // Alacritty (Old)
    '^io\\.alacritty$',
    // Hyper
    '^co\\.zeit\\.hyper$',
    // iTerm2
    '^com\\.googlecode\\.iterm2$',
    // Terminal
    '^com\\.apple\\.Terminal$',
    // WezTerm
    '^com\\.github\\.wez\\.wezterm$',
    // Ghostty
    '^com\\.mitchellh\\.ghostty$',
  ],

  // bundle identifiers for web browser applications
  webBrowsers: [
    // Google Chrome
    '^com\\.google\\.chrome$',
    '^com\\.google\\.Chrome$',
    // Mozilla Firefox
    '^org\\.mozilla\\.firefox$',
    '^org\\.mozilla\\.nightly$',
    // Brave Browser
    '^com\\.brave\\.Browser$',
    // Safari
    '^com\\.apple\\.Safari$',
  ],
}
