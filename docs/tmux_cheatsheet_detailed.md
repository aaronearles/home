# Tmux Cheatsheet

## Session Management

```bash
tmux                           # Start a new session
tmux new -s session_name       # Start a new session with name
tmux ls                        # List all sessions
tmux attach                    # Attach to last session
tmux attach -t session_name    # Attach to specific session
tmux kill-session -t name      # Kill specific session
tmux kill-server               # Kill tmux server and all sessions
```

## Prefix Key
The default prefix key is `Ctrl+b`. All shortcuts below require pressing prefix first.

## Window Management
```
c           # Create new window
w           # List windows
n           # Next window
p           # Previous window
f           # Find window by name
,           # Rename current window
&           # Close current window
0-9         # Switch to window number
```

## Pane Management
```
%           # Split pane vertically
"           # Split pane horizontally
←↑↓→        # Navigate between panes
x           # Kill current pane
z           # Toggle pane zoom
q           # Show pane numbers
o           # Switch to next pane
}           # Swap with next pane
{           # Swap with previous pane
!           # Convert pane into a window
Ctrl+←↑↓→   # Resize pane (hold Ctrl key)
```

## Session Management (with Prefix)
```
d           # Detach from session
s           # List sessions
$           # Rename session
)           # Next session
(           # Previous session
```

## Copy Mode
```
[           # Enter copy mode
Space       # Start selection
Enter       # Copy selection
]           # Paste selection
```

## Misc
```
t           # Show time
:           # Enter command mode
?           # List all shortcuts
```

## Configuration File
The tmux configuration file is located at `~/.tmux.conf`

## Common Commands in Command Mode
```
:new-window                # Create new window
:kill-window              # Kill current window
:split-window             # Split window horizontally
:split-window -h          # Split window vertically
:setw synchronize-panes   # Toggle synchronise-panes
```

## Custom Key Bindings (add to ~/.tmux.conf)
```bash
# Example: Change prefix to Ctrl+a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Example: Reload config file
bind r source-file ~/.tmux.conf \; display "Config reloaded!"
```

Note: To execute commands after entering tmux, press the prefix key (default: Ctrl+b) followed by the command key.