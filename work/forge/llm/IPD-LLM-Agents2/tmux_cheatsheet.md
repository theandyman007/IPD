# tmux Cheat Sheet

**Note:** `Ctrl+B` is the tmux prefix key — press and release it before entering any shortcut.

---

## Sessions

| Command | Description |
|---------|-------------|
| `tmux new -s name` | Create a new named session |
| `tmux attach -t name` | Attach to an existing session by name |
| `tmux ls` | List all active sessions |
| `tmux kill-session -t name` | Kill a session by name |
| `Ctrl+B` then `D` | Detach from the current session (leaves it running) |
| `exit` | Close the current session entirely (only once all processes inside have finished) |

---

## Windows (Tabs)

Windows are like tabs within a session — useful if you want to run multiple things in the same session, for example running a script in one window and monitoring logs in another.

| Command | Description |
|---------|-------------|
| `Ctrl+B` then `C` | Create a new window |
| `Ctrl+B` then `N` | Move to the next window |
| `Ctrl+B` then `P` | Move to the previous window |
| `Ctrl+B` then `0-9` | Jump to a window by number |
| `Ctrl+B` then `,` | Rename the current window |
| `Ctrl+B` then `W` | Show a list of all windows to select from |

---

## Panes (Split Screen)

Panes split a window into multiple terminals side by side or stacked — useful for watching logs while a script runs.

| Command | Description |
|---------|-------------|
| `Ctrl+B` then `%` | Split pane vertically (left/right) |
| `Ctrl+B` then `"` | Split pane horizontally (top/bottom) |
| `Ctrl+B` then arrow key | Move between panes |
| `Ctrl+B` then `X` | Close the current pane |
| `Ctrl+B` then `Z` | Zoom in/out on the current pane (toggle fullscreen) |

---

## Scrolling

By default you cannot scroll up in tmux with the mouse wheel. Use the following to enter and exit scroll mode.

| Command | Description |
|---------|-------------|
| `Ctrl+B` then `[` | Enter scroll mode (use arrow keys or Page Up/Down to scroll) |
| `Q` | Exit scroll mode |

---

## Useful Patterns for This Project

**Start a protected test run:**
```bash
tmux new -s capacity_test
./run_METRICS_TESTING.sh
```

**Watch game logs in a split pane while the script runs:**
```bash
# In one pane, run the script
./run_METRICS_TESTING.sh

# Split the window (Ctrl+B then "), then in the new pane:
tail -f ./outputs/capacity_testing/games/episodic_game_*.log
```

**Reconnect after a dropped SSH connection:**
```bash
tmux attach -t capacity_test
```

**Check if any sessions are running after reconnecting:**
```bash
tmux ls
```