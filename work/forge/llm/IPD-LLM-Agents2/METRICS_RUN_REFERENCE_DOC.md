# `run_METRICS_TESTING.sh` Reference

**Purpose:** Runs one or more Iterated Prisoner's Dilemma (IPD) games in parallel while capturing per-game timing metrics and GPU utilization data for server capacity analysis.

author's note:
currently out of date
---

## Usage

```bash
./run_METRICS_TESTING.sh        # runs with confirmation prompts
./run_METRICS_TESTING.sh -y     # skips the test case confirmation prompt
```

---

## Script Structure Overview

| Section | Description |
|---------|-------------|
| `ERROR HANDLING` | Sets shell behavior — stops on errors, optional debug mode |
| `TEST CASES` | User-defined list of game configurations to run |
| `DEFAULT PARAMETERS` | Fallback values applied to any test case that doesn't override them |
| `RUNNER FUNCTION` | Defines `run_experiment()` — called once per game launch |
| `GUARD RAILS` | Pre-flight checks before any execution begins |
| `BATCH EXECUTION` | Active execution — creates directories, starts GPU monitor, launches games, waits for completion |

---

## Section Details

### ERROR HANDLING

```bash
#set -x       # uncomment to print each command as it runs (debug mode)
set -e        # exit immediately if any command returns a non-zero exit code
```

### TEST CASES

Each entry in the `TESTS` array defines one game configuration to run. Format:

```bash
"label|key=value key=value ..."
```

- **label** — used in output filenames. If left blank, the override values are used as the filename instead.
- **key=value pairs** — space-separated overrides. Only include keys you want to change from the defaults.

**Example:**
```bash
TESTS=(
    "testing_capacity_script|episodes=10 rounds=1 host_0=nickel host_1=nickel"
)
```

**Available keys:**

| Key | Description |
|-----|-------------|
| `episodes` | Number of episodes (periods) to play |
| `rounds` | Number of rounds per episode |
| `window` | History context window size (past rounds visible to agents, default 10) |
| `temp` | Sampling temperature, 0.0–2.0 (0.3 deterministic, 0.7 default, 1.2 exploratory) |
| `model_0` | Ollama model identifier for Agent 0 |
| `model_1` | Ollama model identifier for Agent 1 |
| `host_0` | Server hostname for Agent 0 (e.g. `nickel`, `zinc`, `copper`, `iron`, `tungsten`) |
| `host_1` | Server hostname for Agent 1 |
| `system_prompt` | Path to system prompt file (default: `system_prompt.txt`) |
| `reflection_template` | Path to reflection template file (default: `reflection_prompt_template.txt`) |
| `reflection_type` | Reflection verbosity: `minimal`, `standard`, or `detailed` (default: `standard`) |
| `no_reset` | Prevent context reset between episodes: `true` or `false` |
| `repeat` | Number of times to repeat this test case (default: 1) |

**Note:** `repeat` is handled by the launch loop and is not passed to the Python script.

### DEFAULT PARAMETERS

Values applied to every test case unless explicitly overridden. All optional parameters default to blank, which allows `episodic_ipd_game.py` to use its own internal defaults.

```bash
results_dir="./outputs/capacity_testing/games"
metrics_dir="./outputs/capacity_testing/metrics"
DEFAULT_NO_RESET=true
DEFAULT_REPEAT=1
# all other defaults are blank
```

### RUNNER FUNCTION

`run_experiment()` is called once per game. It:
1. Applies any overrides on top of the defaults
2. Builds the `python episodic_ipd_game.py` command string
3. Wraps the command to capture start time, end time, and exit code
4. Launches the wrapped command in the background using `nohup`
5. Appends a row to the batch metrics CSV when the game finishes

Games run in parallel as background processes. The script does not wait for one game to finish before launching the next.

### GUARD RAILS

Two checks run before any execution:

**tmux check** — detects whether the script is running inside a tmux session by checking the `$TMUX` environment variable. If not in tmux, warns the user and prompts for confirmation before continuing. Running without tmux risks orphaning the GPU monitor if the SSH connection drops.

**Test case confirmation** — prints the current `TESTS` array and prompts the user to confirm before launching. Skipped if the `-y` flag is supplied.

### BATCH EXECUTION

This section performs all active work in the following order:

1. **Creates output directories** if they don't already exist
2. **Sets `batch_timestamp`** — a single timestamp shared across all files in this batch, used to tie the metrics CSV, GPU log, and game outputs together
3. **Creates the CSV header** for the game metrics file
4. **Starts the GPU monitor** (`nvidia-smi dmon`) as a background process, logging all GPUs every 2 seconds with timestamps
5. **Sets a trap** — if the script is interrupted (`Ctrl+C`), the GPU monitor is automatically killed before exiting
6. **Launches all test cases** from the `TESTS` array, using `repeat` to run multiple instances if specified
7. **Waits** (`wait`) for all background game processes to finish
8. **Kills the GPU monitor** and prints completion messages

---

## Output Files

All outputs are written to subdirectories of `./outputs/capacity_testing/`. Files from the same batch share the same `TIMESTAMP` in their filenames.

```
./outputs/capacity_testing/
    games/
        episodic_game_TIMESTAMP_LABEL.json    -- full game output
        episodic_game_TIMESTAMP_LABEL.log     -- stdout/stderr for each game
    metrics/
        game_metrics_TIMESTAMP.csv            -- per-game config and timing
        gpu_TIMESTAMP.log                     -- GPU utilization during the batch
```

For full details on the metrics file format, see `metrics_reference.md`.

---

## Interruption Behavior

| Scenario | Games | GPU Monitor |
|----------|-------|-------------|
| Script runs to completion | Finish normally | Stopped cleanly by `kill` |
| `Ctrl+C` during execution | Continue running (protected by `nohup`) | Stopped cleanly by `trap` |
| SSH disconnection (inside tmux) | Continue running | Continues running, stopped when `wait` completes |
| SSH disconnection (outside tmux) | Continue running | Orphaned — runs indefinitely, must be killed manually |

**If the GPU monitor is orphaned**, find and kill it with:
```bash
ps aux | grep nvidia-smi
kill <PID>
```

---

## Related Files

| File | Description |
|------|-------------|
| `episodic_ipd_game.py` | The Python game script called by this runner |
| `system_prompt.txt` | Default system prompt for agents |
| `reflection_prompt_template.txt` | Default reflection template for agents |
| `metrics_reference.md` | Detailed reference for metrics output file formats |
| `tmux_cheatsheet.md` | tmux commands for managing sessions |