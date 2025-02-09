SESS="my_tmux_session"

tmux has-session -t $SESS 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -d -s $SESS -n "editor"

    tmux send-keys -t $SESS:editor "cd ./project" C-m
    tmux send-keys -t $SESS:editor "nano ." C-m

    tmux new-window -t $SESS -n "server"
    tmux send-keys -t $SESS:server "cd ./project" C-m
    tmux send-keys -t $SESS:server "echo This is just a test" C-m

    tmux set-option -t $SESS status on
    # tmux set-option -t $SESS status-style fg=white,bg=black
    # tmux set-option -t $SESS status-left "#[fg=green]Session: #S #[fg=yello]"
    # tmux set-option -t $SESS status-left-length 40
    # tmux set-option -t $SESS status-right "#[fg=cyan]%d %b %R"

    # tmux set-window-option -t $SESS window-status-style fg=cyan,bg=black
    # tmux set-window-option -t $SESS window-status-current-style fg=white,bg=black

    tmux select-window -t $SESS:editor

fi

tmux attach-session -t $SESS