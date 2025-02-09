# Tmux Quick Reference
## Prefix Key: Ctrl+b (press prefix before each command)

### Session Controls
```
tmux                    # New session
tmux new -s name       # New named session
tmux ls                # List sessions
tmux attach           # Attach last session
tmux attach -t name    # Attach named session
tmux kill-session -t name    # Kill session
d                      # Detach current session
$                      # Rename session
```

### Window Controls
```
c    # Create window     w    # List windows
n    # Next window       p    # Previous window
,    # Rename window     &    # Kill window
0-9  # Switch to window number
```

### Pane Controls
```
%    # Split vertical    "    # Split horizontal
←↑↓→  # Navigate panes    x    # Kill pane
z    # Toggle zoom       o    # Next pane
q    # Show pane numbers
Ctrl+←↑↓→               # Resize pane
```

### Copy Mode (prefix + [ to start)
```
Space  # Start selection    Enter  # Copy selection
]      # Paste selection    q      # Quit copy mode
```

### Other
```
?    # Show shortcuts    :    # Command mode
t    # Show time        r    # Reload config
```

Config: ~/.tmux.conf
Common command mode: :new-window, :kill-window, :split-window

*Note: Print in landscape mode for best results*