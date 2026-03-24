#!/bin/bash

##usage
# ./run_METRICS_TESTING.sh      ## this runs the experiment, prompting for confirmation
# ./run_METRICS_TESTINGS.sh -y   ## this skips the confirmation prompt

# ============================================================
# To do:
# - add ability to stagger start times of games
# - add ability to run games sequentially rather than in parallel (for debugging or low-resource scenarios)
# - consider more intelligent staggering based on expected game length or GPU load, rather than fixed sleep
# ============================================================


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
#   delay         -- before launching: a number of seconds to sleep, or "wait" to block until the previous test finishes

TESTS=(
    "high_temp|episodes=30 rounds=20 temp=1.2 host_0=tungsten host_1=tungsten repeat=5"
    "mid_temp|episodes=30 rounds=20 temp=0.7 host_0=tungsten host_1=tungsten repeat=5"    
    "low_temp|episodes=30 rounds=20 temp=0.3 host_0=tungsten host_1=tungsten repeat=5"    
)

# ============================================================
# DEFAULT PARAMETERS
# ============================================================
# Applied to every run unless overridden in a test case above.
# Leave optional args blank to omit them from the command entirely,
# allowing episodic_ipd_game.py to use its own internal defaults.

# setup for below directories performed in BATCH EXECUTION
results_dir="./outputs/capacity_testing/games"     # base dir; batch subdir derived after timestamp is set
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
DEFAULT_DELAY=0

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
    local delay=$DEFAULT_DELAY

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
            delay)              ;; # handled in loop, not passed to python
        esac
    done

    local run_name="episodic_game_${temp_timestamp}_${label}"

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
    CMD+=" --output ${batch_results_dir}/${run_name}.json"

    # Wrap the game command to record absolute start/end timestamps and exit status,
    # then append a row to the shared CSV for this batch.
    #
    # Columns written:
    #   batch_id       -- shared timestamp across the whole batch (groups runs together)
    #   run_name       -- unique name for this specific run
    #   start_time     -- Unix epoch seconds when the game process started
    #   end_time       -- Unix epoch seconds when it finished
    #   elapsed_seconds -- derived from end-start for convenience
    #   episodes/rounds/window/temp/model_*/host_* -- config params
    #   exit_code      -- 0 = success
    #
    # Having start_time + end_time (rather than just elapsed) lets you compute
    # concurrency in post-processing: count how many runs have overlapping
    # [start_time, end_time] intervals at any given moment.


    local WRAPPED="
        start_time=\$(date +%s);
        $CMD;
        exit_code=\$?;
        end_time=\$(date +%s);
        elapsed=\$((end_time - start_time));
        csv_episodes=\"${episodes:-default}\";
        csv_rounds=\"${rounds:-default}\";
        csv_window=\"${window:-default}\";
        csv_temp=\"${temp:-default}\";
        csv_model_0=\"${model_0:-default}\";
        csv_model_1=\"${model_1:-default}\";
        csv_host_0=\"${host_0:-default}\";
        csv_host_1=\"${host_1:-default}\";
        echo \"${batch_timestamp},${run_name},\${start_time},\${end_time},\${elapsed},\${csv_episodes},\${csv_rounds},\${csv_window},\${csv_temp},\${csv_model_0},\${csv_model_1},\${csv_host_0},\${csv_host_1},\${exit_code}\" >> \"${game_metrics_file}\";
    "

    nohup bash -c "$WRAPPED" > "${batch_results_dir}/${run_name}.log" 2>&1 &
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

# Timestamp shared across this entire batch (used for filenames and batch_id column)
batch_timestamp=$(date +%Y%m%d_%H%M%S)

# Per-batch subfolder for game outputs: ./outputs/capacity_testing/games/<batch_timestamp>/
batch_results_dir="${results_dir}/${batch_timestamp}"

# Create output directories if not present
mkdir -p "$batch_results_dir"
mkdir -p "$metrics_dir"

# --- CSV header (one file per batch) ---
# start_time and end_time are Unix epoch seconds.
# elapsed_seconds is included as a convenience column (end_time - start_time).
# Concurrency at any point = count of rows where start_time <= T <= end_time.
game_metrics_file="${metrics_dir}/${batch_timestamp}_game_metrics.csv"
echo "batch_id,run_name,start_time,end_time,elapsed_seconds,episodes,rounds,window,temp,model_0,model_1,host_0,host_1,exit_code" \
    > "$game_metrics_file"

# --- GPU monitor: log GPUs on worker servers for this batch ---
# Monitors are launched via SSH onto each unique host used across all test cases.
# Each host gets its own log file: gpu_<host>_<timestamp>.log
# stdbuf -oL forces line-buffered output so each line is written to the file immediately.
declare -A GPU_MON_PIDS  # tracks one monitor PID per unique host

for test_entry in "${TESTS[@]}"; do
    overrides="${test_entry#*|}"

    # Extract host_0 and host_1 from this test's overrides (fall back to defaults)
    h0="${DEFAULT_HOST_0}"
    h1="${DEFAULT_HOST_1}"
    for kv in $overrides; do
        [[ "${kv%%=*}" == "host_0" ]] && h0="${kv#*=}"
        [[ "${kv%%=*}" == "host_1" ]] && h1="${kv#*=}"
    done

    for host in "$h0" "$h1"; do
        [[ -z "$host" ]] && continue                    # skip if host is unset
        [[ -n "${GPU_MON_PIDS[$host]}" ]] && continue  # skip if already monitoring this host

        gpu_log="${metrics_dir}/${batch_timestamp}_${host}_continuous_gpu.csv"
        ssh "$host" "nvidia-smi dmon -s mu -d 2 -o DT --format csv" \
            >> "$gpu_log" &
        GPU_MON_PIDS[$host]=$!
        echo "GPU monitor started on $host (PID ${GPU_MON_PIDS[$host]}) → $gpu_log"
    done
done

# Trap INT/TERM to cleanly kill all GPU monitors if the script is interrupted
trap 'echo "Interrupted. Stopping GPU monitors..."; for pid in "${GPU_MON_PIDS[@]}"; do kill "$pid" 2>/dev/null; done; exit 1' INT TERM

# --- Launch all test cases ---
GAME_PIDS=()
PREV_PIDS=()  # tracks PIDs of previously launched games (for optional staggering)(used by delay=wait)

 for test_entry in "${TESTS[@]}"; do
     label="${test_entry%%|*}"
     overrides="${test_entry#*|}"
 
     #Capture timestamp for repeated tests
     temp_timestamp=$(date +%Y%m%d_%H%M%S)
 
     # Extract repeat count if specified, default to 1
     repeat=$DEFAULT_REPEAT
     delay=$DEFAULT_DELAY      

     for kv in $overrides; do
         [[ "${kv%%=*}" == "repeat" ]] && repeat="${kv#*=}"
        [[ "${kv%%=*}" == "delay" ]]  && delay="${kv#*=}"
     done
 
    # Apply delay before launching this test's runs
    if [[ "$delay" == "wait" ]]; then
        if [[ ${#PREV_PIDS[@]} -gt 0 ]]; then
            echo "Waiting for previous test to finish before launching: $label"
            for pid in "${PREV_PIDS[@]}"; do
                wait "$pid" 2>/dev/null || true
            done
        fi
    elif [[ -n "$delay" ]] && [[ "$delay" =~ ^[0-9]+$ ]]; then
        echo "Sleeping ${delay}s before launching: $label"
        sleep "$delay"
    fi

    THIS_PIDS=()
     for ((i=1; i<=repeat; i++)); do
         if [[ -z "$label" ]]; then
             run_label="${overrides//[ =]/_}"
         else
             run_label="$label"
         fi
         [[ $repeat -gt 1 ]] && run_label="${run_label}_run${i}"
         run_experiment "$run_label" "$overrides" "$temp_timestamp"
         GAME_PIDS+=($!)  # capture each game's PID
        THIS_PIDS+=($!)
     done
    PREV_PIDS=("${THIS_PIDS[@]}")
    done
#===========================================
# below code is the original version without delay handling; keep for reference until delay logic is confirmed working.
#===========================================
# for test_entry in "${TESTS[@]}"; do
#     label="${test_entry%%|*}"
#     overrides="${test_entry#*|}"

#     #Capture timestamp for repeated tests
#     temp_timestamp=$(date +%Y%m%d_%H%M%S)

#     # Extract repeat count if specified, default to 1
#     repeat=$DEFAULT_REPEAT
#     for kv in $overrides; do
#         [[ "${kv%%=*}" == "repeat" ]] && repeat="${kv#*=}"
#     done

#     for ((i=1; i<=repeat; i++)); do
#         if [[ -z "$label" ]]; then
#             run_label="${overrides//[ =]/_}"
#         else
#             run_label="$label"
#         fi
#         [[ $repeat -gt 1 ]] && run_label="${run_label}_run${i}"
#         run_experiment "$run_label" "$overrides" "$temp_timestamp"
#         GAME_PIDS+=($!)  # capture each game's PID
#     done

#     #===========================================
#     # comment out sleep to run all games as fast as possible;
#     # todo: consider more intelligent staggering based on expected game length or GPU load, rather than fixed sleep
#     # stagger launches to reduce initial load spikes; 
#     # testing if staggering improves performance
#     # testing how concurrency performance evolves over time as games finish and new ones start
#     #===========================================
#     #sleep 10 

# done

echo ""
echo "To view progress, use command: tail -f ${batch_results_dir}/episodic_game_*.log"
echo ""
echo "Waiting for all games to finish before stopping GPU monitors..."

# Wait ONLY on game processes (not GPU monitors)
for pid in "${GAME_PIDS[@]}"; do
    wait "$pid"
done

# Now stop all GPU monitors
for host in "${!GPU_MON_PIDS[@]}"; do
    kill "${GPU_MON_PIDS[$host]}" 2>/dev/null
    echo "GPU monitor stopped on $host."
done
echo "Metrics written to: $metrics_dir/"