// macboard — make a Mac keyboard behave like a Windows/Linux (QWERTY) keyboard
// for a Linux/Windows developer's muscle memory.
//
// This file LAYERS our amendments on top of the vendored rux616/karabiner-windows-mode
// ruleset (windows_shortcuts.jsonnet), which provides the core Ctrl->Cmd "matrix"
// plus Windows-style navigation keys and terminal/IDE exemptions.
//
// The Globe->Control mapping is NOT here: it is a profile-level *simple modification*
// (`fn -> left_control`) applied by the installer, because Karabiner runs simple
// modifications BEFORE complex modifications. That ordering is what lets Globe+C arrive
// at this matrix as `control+c` and get rewritten to `command+c` (copy) outside
// terminals, while passing through raw as SIGINT inside terminals.
//
// ORDER MATTERS: our amendment rules are concatenated BEFORE the windows-mode rules so
// that, on first-match-wins, the Right-Option media layer beats windows-mode's generic
// `option+f4 -> Cmd+Q` / `option+tab -> Cmd+Tab` rules (those use bare `option`, which
// also matches right_option). Our media rules require `right_option` specifically.

local k = import 'lib/karabiner.libsonnet';
local ws = import 'windows_shortcuts.jsonnet';
local bundle = import 'lib/bundle.libsonnet';
local file_paths = import 'lib/file_paths.libsonnet';

//-------------------------------------------------------------------//
// RIGHT-OPTION MEDIA LAYER                                           //
// Top row is real F1-F12 (installer sets fnState=true). Because the  //
// Globe/fn layer is gone, the rare Mac system ops live on Right ⌥.   //
// Mirrors the stock Apple top row.                                   //
//-------------------------------------------------------------------//
local mediaLayer = [
  k.rule('[macboard] Media: Right-Option+F1 -> Brightness Down',
         k.input('f1', ['right_option']),
         k.outputKey('display_brightness_decrement')),
  k.rule('[macboard] Media: Right-Option+F2 -> Brightness Up',
         k.input('f2', ['right_option']),
         k.outputKey('display_brightness_increment')),
  k.rule('[macboard] Media: Right-Option+F3 -> Mission Control',
         k.input('f3', ['right_option']),
         k.outputKey('mission_control')),
  k.rule('[macboard] Media: Right-Option+F4 -> Spotlight (Cmd+Space)',
         k.input('f4', ['right_option']),
         k.outputKey('spacebar', ['command'])),
  k.rule('[macboard] Media: Right-Option+F5 -> Keyboard Backlight Down',
         k.input('f5', ['right_option']),
         k.outputKey('illumination_decrement')),
  k.rule('[macboard] Media: Right-Option+F6 -> Keyboard Backlight Up',
         k.input('f6', ['right_option']),
         k.outputKey('illumination_increment')),
  k.rule('[macboard] Media: Right-Option+F7 -> Previous Track',
         k.input('f7', ['right_option']),
         k.outputKey('rewind')),
  k.rule('[macboard] Media: Right-Option+F8 -> Play/Pause',
         k.input('f8', ['right_option']),
         k.outputKey('play_or_pause')),
  k.rule('[macboard] Media: Right-Option+F9 -> Next Track',
         k.input('f9', ['right_option']),
         k.outputKey('fastforward')),
  k.rule('[macboard] Media: Right-Option+F10 -> Mute',
         k.input('f10', ['right_option']),
         k.outputKey('mute')),
  k.rule('[macboard] Media: Right-Option+F11 -> Volume Down',
         k.input('f11', ['right_option']),
         k.outputKey('volume_decrement')),
  k.rule('[macboard] Media: Right-Option+F12 -> Volume Up',
         k.input('f12', ['right_option']),
         k.outputKey('volume_increment')),
];

//-------------------------------------------------------------------//
// SCREENSHOT KEYS                                                    //
// "PrintScreen" means EVERY way of asking for a screenshot: the      //
// external QWERTY's PrintScreen key and the Mac's own Cmd+Shift+3/4/ //
// 5. They all land on the same tool, so the answer does not depend   //
// on which keyboard is in hand or which habit fires first.           //
//-------------------------------------------------------------------//
local screenshotRules(shottr_capture) =
  // A macOS Cmd+Shift+<digit> key that Shottr already owns is left alone -- remapping it
  // to itself would be a cycle.
  local ownedByShottr(digit, target) =
    target != null &&
    target.key_code == digit &&
    std.set(target.modifiers) == std.set(['command', 'shift']);
  local toShottr(digit, what, target) =
    if target == null || ownedByShottr(digit, target) then [] else [
      k.rule('[macboard] Cmd+Shift+' + digit + ' -> Shottr ' + what + ' (' + target.label + ')',
             k.input(digit, ['command', 'shift']),
             k.outputKey(target.key_code, target.modifiers)),
    ];
  if shottr_capture != null then
    [
      k.rule('[macboard] PrintScreen -> Shottr area capture (' + shottr_capture.area.label + ')',
             k.input('print_screen'),
             k.outputKey(shottr_capture.area.key_code, shottr_capture.area.modifiers)),
    ]
    // Each native macOS screenshot key keeps its meaning, served by Shottr instead:
    // Cmd+Shift+3 grabs the screen, Cmd+Shift+4 and the Cmd+Shift+5 toolbar grab an area.
    + toShottr('3', 'full screen', shottr_capture.fullscreen)
    + toShottr('4', 'area capture', shottr_capture.area)
    + toShottr('5', 'area capture', shottr_capture.area)
  else
    [
      k.rule('[macboard] PrintScreen -> Screenshot toolbar (Cmd+Shift+5)',
             k.input('print_screen'),
             k.outputKey('5', ['command', 'shift'])),
    ];

//-------------------------------------------------------------------//
// AUXILIARY / QUERY KEYS                                             //
//-------------------------------------------------------------------//
local auxKeys = [
  // The built-in keyboard has no forward-delete key (fn+Delete is gone now that
  // Globe = Control). Give it back on Right-Option+Backspace. Does not collide with
  // the media layer (that is Right-Option + F-row only).
  k.rule('[macboard] Right-Option+Backspace -> Forward Delete (built-in board)',
         k.input('delete_or_backspace', ['right_option']),
         k.outputKey('delete_forward')),
];

//-------------------------------------------------------------------//
// FINDER: make the Windows Delete key remove files like on Windows. //
// Plain forward-delete still works in text everywhere else.         //
//-------------------------------------------------------------------//
local finder = ['^com\\.apple\\.finder$'];
local finderDelete = [
  k.rule('[macboard] Finder: Delete -> Move to Trash (Cmd+Delete)',
         k.input('delete_forward'),
         k.outputKey('delete_or_backspace', ['command']),
         k.condition('if', finder)),
  k.rule('[macboard] Finder: Shift+Delete -> Delete Immediately (Cmd+Opt+Delete)',
         k.input('delete_forward', ['shift']),
         k.outputKey('delete_or_backspace', ['command', 'option']),
         k.condition('if', finder)),
];

//-------------------------------------------------------------------//
// ALT+TAB FALLBACK (conditional)                                    //
// has_alttab (top-level arg, default false):                        //
//   true  -> the AltTab app is installed+running and owns Alt+Tab,  //
//            so we leave Option+Tab RAW for its per-WINDOW switcher. //
//   false -> no AltTab; restore windows-mode's Option+Tab -> Cmd+Tab //
//            remap (the macOS per-APP switcher default).             //
// The installer detects AltTab and passes this via --tla-code; a    //
// bare `jsonnet` render defaults to the no-AltTab (fallback) config. //
//-------------------------------------------------------------------//

//-------------------------------------------------------------------//
// SCREENSHOT TARGET (conditional)                                   //
// shottr_capture (top-level arg, default null):                     //
//   null   -> no Shottr; PrintScreen opens the macOS screenshot     //
//             toolbar and Cmd+Shift+3/4/5 stay native.              //
//   object -> {area, fullscreen, ...}, each {key_code, modifiers,   //
//             label}, read from Shottr's own prefs by the installer //
//             (scripts/shottr_hotkey.py) so a custom binding is     //
//             honoured rather than assumed. PrintScreen and the     //
//             Cmd+Shift+3/4/5 trio all fire Shottr. A null          //
//             fullscreen leaves Cmd+Shift+3 native.                 //
// macboard never installs Shottr -- it is the user's own app.       //
//-------------------------------------------------------------------//

//------//
// MAIN //
//------//
function(has_alttab=false, shottr_capture=null)
  local altTabRules = if has_alttab then [
    // AltTab present: Option+Tab is left RAW (no rule) for its per-window switcher, which
    // already works on the external QWERTY (Alt = Option). On the BUILT-IN keyboard the
    // spacebar-adjacent key is Command, not Option, so redirect ONLY that keyboard's
    // Cmd+Tab -> Option+Tab to feed the same AltTab trigger. device_if is_built_in_keyboard
    // means the external QWERTY never sees this rule -- its Alt+Tab and Cmd+Tab are untouched.
    k.rule('Tab (Cmd) -> Option+Tab [built-in keyboard only; feeds AltTab]',
           k.input('tab', ['command']),
           k.outputKey('tab', ['option']),
           { type: 'device_if', identifiers: [{ is_built_in_keyboard: true }] }),
  ] else [
    // No AltTab: restore windows-mode's Option+Tab -> Cmd+Tab (the macOS app-switcher).
    k.rule('Tab (Alt) -> Cmd+Tab [fallback: AltTab not installed/running]',
           k.input('tab', ['option']),
           k.outputKey('tab', ['command']),
           k.condition('unless', bundle.hypervisors + bundle.remoteDesktops, file_paths.remoteDesktops)),
  ];
  {
    title: 'macboard (Windows/Linux muscle memory)',
    rules: mediaLayer + screenshotRules(shottr_capture) + auxKeys + finderDelete
           + ws.rules + altTabRules,
  }
