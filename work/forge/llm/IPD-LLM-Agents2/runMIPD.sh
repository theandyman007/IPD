#!/bin/bash

##usage
# ./runMIPD.sh      ## this runs the experiment, prompting for confirmation
# ./runMIPD.sh -y   ## this skips the confirmation prompt


# Print each command as it runs (good for debugging). uncomment to activate
#set -x

# Stop the script if anything errors
set -e




# ============================================================
# TEST CASES
# ============================================================
# Each entry is:  "key=value key=value ..."
# Only include the keys you want to OVERRIDE for that run.
# Examples of test cases:
#       "temp=0.3"
#       "temp=0.7"
#       "temp=1.2"
#       "episodes=30 rounds=20"
#       "system_prompt=my_custom_prompt.txt reflection_type=detailed"
#       "model_0=gpt-4 model_1=gpt-3.5-turbo host_0=nickel host_1=zinc"
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
    #need to run below 20-30+ times
    "episodes=30 rounds=50"

)

# ============================================================
# DEFAULT PARAMETERS
# ============================================================
# Applied to every run unless overridden in a test case above.
# Leave optional args blank to omit them from the command entirely,
# allowing episodic_ipd_game.py to use its own internal defaults.

results_dir="./results_testing"

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
# RUNNER — no need to edit below this line
# ============================================================

run_experiment() {
    local overrides="$1"

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
    local run_name="episodic_game_$(date +%Y%m%d_%H%M%S)"


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

    nohup bash -c "$CMD" > "${results_dir}/${run_name}.log" 2>&1 &
    echo "Launched: $run_name (PID $!)"
}

# Detect -y flag
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

mkdir -p "$results_dir"

for test_entry in "${TESTS[@]}"; do
    overrides="$test_entry"

    # Extract repeat count if specified, default to 1
    repeat=$DEFAULT_REPEAT
    for kv in $overrides; do
        [[ "${kv%%=*}" == "repeat" ]] && repeat="${kv#*=}"
    done
    
    for ((i=1; i<=repeat; i++)); do
        run_experiment "$overrides"
        sleep 1
    done
done

echo "To view progress, use command: tail -f ${results_dir}/episodic_game_*.log"