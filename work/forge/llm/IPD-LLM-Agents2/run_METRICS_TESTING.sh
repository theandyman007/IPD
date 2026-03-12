#!/bin/bash

##usage
# ./run_METRICS_TESTING.sh      ## this runs the experiment, prompting for confirmation
# ./run_METRICS_TESTINGS.sh -y   ## this skips the confirmation prompt


# ============================================================
# ERROR HANDLING
# ============================================================

# Print each command as it runs (good for debugging). uncomment to activate
#set -x

# Stop the script if anything errors
set -e


# ============================================================
# TEST CASES
# ============================================================
# Each entry is:  "label|key=value key=value ..."
# Only include the keys you want to OVERRIDE for that run.
# Label becomes part of the output filename.
# if Label is blank, the changed values will instead be appended to the filename
# Examples of test cases:
#       "temp_low|temp=0.3"
#       "temp_mid|temp=0.7"
#       "temp_high|temp=1.2"
#       "long_game|episodes=30 rounds=20"
#       "custom_prompt|system_prompt=my_custom_prompt.txt reflection_type=detailed"
#       "model_compare|model_0=gpt-4 model_1=gpt-3.5-turbo host_0=nickel host_1=zinc"
#
# Available keys:
#   episodes      -- number of periods to play
#   rounds        -- number of rounds within each episode
#   window        -- history context window size (number of past rounds visible, default 10)
#   temp          -- sampling temp 0.0-2.0 (0.3 deterministic, 0.7 default, 1.2 exploratory)
#   model_0       -- LLM model for agent 0
#   model_1       -- LLM model for agent 1
#   host_0        -- server hostname for agent 0 (nickel, zinc, copper, iron, tungsten)
#   host_1        -- server hostname for agent 1
#   system_prompt       -- path to system prompt file (default: system_prompt.txt)
#   reflection_template -- path to reflection template file (default: reflection_prompt_template.txt)
#   reflection_type     -- reflection verbosity: minimal | standard | detailed (default: standard)
#   no_reset      -- prevents resetting context across episodes (true/false)
#   repeat        -- number of times to repeat the same test case (default: 1)

TESTS=(
    "testing_capacity_script|episodes=10 rounds=1 host_0=nickel host_1=nickel"

)

# ============================================================
# DEFAULT PARAMETERS
# ============================================================
# Applied to every run unless overridden in a test case above.
# Leave optional args blank to omit them from the command entirely,
# allowing episodic_ipd_game.py to use its own internal defaults.

# setup for below directories performed in BATCH EXECUTION
results_dir="./outputs/capacity_testing/games"
metrics_dir="./outputs/capacity_testing/metrics"

DEFAULT_EPISODES=""
DEFAULT_ROUNDS=""
DEFAULT_WINDOW=""
DEFAULT_TEMP=""
DEFAULT_MODEL_0=""
DEFAULT_MODEL_1=""
DEFAULT_HOST_0=""
DEFAULT_HOST_1=""
DEFAULT_SYSTEM_PROMPT=""
DEFAULT_REFLECTION_TEMPLATE=""
DEFAULT_REFLECTION_TYPE=""
DEFAULT_NO_RESET=true
DEFAULT_REPEAT=1

# ============================================================
# RUNNER FUNCTION
# ============================================================
run_experiment() {
    local label="$1"
    local overrides="$2"
    local temp_timestamp="$3"

    # Start from defaults
    local episodes=$DEFAULT_EPISODES
    local rounds=$DEFAULT_ROUNDS
    local window=$DEFAULT_WINDOW
    local temp=$DEFAULT_TEMP
    local model_0=$DEFAULT_MODEL_0
    local model_1=$DEFAULT_MODEL_1
    local host_0=$DEFAULT_HOST_0
    local host_1=$DEFAULT_HOST_1
    local system_prompt=$DEFAULT_SYSTEM_PROMPT
    local reflection_template=$DEFAULT_REFLECTION_TEMPLATE
    local reflection_type=$DEFAULT_REFLECTION_TYPE
    local no_reset=$DEFAULT_NO_RESET
    local repeat=$DEFAULT_REPEAT

    # Apply overrides (space-separated key=value pairs)
    for kv in $overrides; do
        local key="${kv%%=*}"
        local val="${kv#*=}"
        case "$key" in
            episodes)            episodes="$val" ;;
            rounds)              rounds="$val" ;;
            window)              window="$val" ;;
            temp)                temp="$val" ;;
            model_0)             model_0="$val" ;;
            model_1)             model_1="$val" ;;
            host_0)              host_0="$val" ;;
            host_1)              host_1="$val" ;;
            system_prompt)       system_prompt="$val" ;;
            reflection_template) reflection_template="$val" ;;
            reflection_type)     reflection_type="$val" ;;
            no_reset)            no_reset="$val" ;;
            repeat)             ;; # handled in loop, not passed to python
        esac
    done

    local run_name="episodic_game_${temp_timestamp}_${label}"
    local game_metrics_file="${metrics_dir}/game_metrics_${batch_timestamp}.csv"

    # Build command
    local CMD="python episodic_ipd_game.py"
    [[ "$no_reset" == "true" ]]         && CMD+=" --no-reset"
    [[ -n "$episodes" ]]                && CMD+=" --episodes $episodes"
    [[ -n "$rounds" ]]                  && CMD+=" --rounds $rounds"
    [[ -n "$window" ]]                  && CMD+=" --history-window $window"
    [[ -n "$temp" ]]                    && CMD+=" --temperature $temp"
    [[ -n "$model_0" ]]                 && CMD+=" --model-0 $model_0"
    [[ -n "$model_1" ]]                 && CMD+=" --model-1 $model_1"
    [[ -n "$host_0" ]]                  && CMD+=" --host-0 $host_0"
    [[ -n "$host_1" ]]                  && CMD+=" --host-1 $host_1"
    [[ -n "$system_prompt" ]]           && CMD+=" --system-prompt $system_prompt"
    [[ -n "$reflection_template" ]]     && CMD+=" --reflection-template $reflection_template"
    [[ -n "$reflection_type" ]]         && CMD+=" --reflection-type $reflection_type"
    CMD+=" --output ${results_dir}/${run_name}.json"

    # Wrap the game command to record start time, end time, and exit status,
    # then append a row to the shared CSV for this batch.
    local WRAPPED="
        start_time=\$(date +%s);
        $CMD;
        exit_code=\$?;
        end_time=\$(date +%s);
        elapsed=\$((end_time - start_time));
        echo \"${run_name},${episodes},${rounds},${window},${temp},${model_0},${model_1},${host_0},${host_1},\${elapsed},\${exit_code}\" >> \"${game_metrics_file}\";
    "

    nohup bash -c "$WRAPPED" > "${results_dir}/${run_name}.log" 2>&1 &
    echo "Launched: $run_name (PID $!)"
}


# ============================================================
# GUARD RAILS
# ============================================================

# Detect if tmux is active (protects from dropped SSH sessions)
if [ -z "$TMUX" ]; then
    echo ""
    echo "Warning: you do not appear to be inside a tmux session."
    echo "Running without tmux risks losing the GPU monitor and wait block if your SSH connection drops."
    echo ""
    read -p "Are you running inside tmux? (y/n): " tmux_confirm
    [[ "$tmux_confirm" != "y" ]] && echo "Exiting. Start tmux with: tmux new -s capacity_test" && exit 1
    echo ""
fi

# Detect -y flag (confirms test cases to run)
SKIP_CONFIRM=false
[[ "${1:-}" == "-y" ]] && SKIP_CONFIRM=true

if [[ "$SKIP_CONFIRM" == "false" ]]; then
    echo ""
    echo "Current test cases:"
    for test_entry in "${TESTS[@]}"; do
        echo "  $test_entry"
    done
    echo ""
    read -p "Are these the tests you want to run? (y/n): " confirm
    [[ "$confirm" != "y" ]] && echo "Aborted." && exit 1
    echo ""
fi


# ============================================================
# BATCH EXECUTION
# ============================================================

# Create output directories if not present
mkdir -p "$results_dir"
mkdir -p "$metrics_dir"

# Timestamp shared across this entire batch (used for filenames)
batch_timestamp=$(date +%Y%m%d_%H%M%S)

# --- CSV header (one file per batch) ---
game_metrics_file="${metrics_dir}/game_metrics_${batch_timestamp}.csv"
echo "run_name,episodes,rounds,window,temp,model_0,model_1,host_0,host_1,elapsed_seconds,exit_code" \
    > "$game_metrics_file"

# --- GPU monitor: log all GPUs on this machine for the duration of the batch ---
gpu_log="${metrics_dir}/gpu_${batch_timestamp}.log"
nvidia-smi dmon -s mu -d 2 \
    | awk '{print strftime("%Y-%m-%dT%H:%M:%S"), $0; fflush()}' \
    >> "$gpu_log" &
GPU_MON_PID=$!
trap 'echo "Interrupted. Stopping GPU monitor..."; kill $GPU_MON_PID 2>/dev/null; exit 1' INT TERM
echo "GPU monitor started (PID $GPU_MON_PID) → $gpu_log"

# --- Launch all test cases ---
for test_entry in "${TESTS[@]}"; do
    label="${test_entry%%|*}"
    overrides="${test_entry#*|}"

    #Capture timestamp for repeated tests
    temp_timestamp=$(date +%Y%m%d_%H%M%S)

    # Extract repeat count if specified, default to 1
    repeat=$DEFAULT_REPEAT
    for kv in $overrides; do
        [[ "${kv%%=*}" == "repeat" ]] && repeat="${kv#*=}"
    done

    for ((i=1; i<=repeat; i++)); do
        if [[ -z "$label" ]]; then
            run_label="${overrides//[ =]/_}"
        else
            run_label="$label"
        fi
        [[ $repeat -gt 1 ]] && run_label="${run_label}_run${i}"
        run_experiment "$run_label" "$overrides" "$temp_timestamp"
    done
done

echo ""
echo "To view progress, use command: tail -f ${results_dir}/episodic_game_*.log"
echo ""
echo "Waiting for all games to finish before stopping GPU monitor..."

# Wait for all background game processes to finish, then stop GPU monitor
wait
kill $GPU_MON_PID
echo "GPU monitor stopped."
echo "Metrics written to: $metrics_dir/"