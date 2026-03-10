#!/bin/bash
####################################################
#         python episodic_ipd_game.py \

# #  prevents resetting context across episodes
#             --no-reset \                  

# #  number of periods to play
#             --episodes ${episodes} \      

# #  number of rounds within each episode
#             --rounds ${rounds} \          

# #  sampling temp, 0.0 - 2.0. default 0.7. 
# #  lower = more deterministic. 0.3 very deterministic
# #  higher = more exploratory. 1.2 more exploratory
#             --temperature ${temp} \       

# #  context window size (in number of past rounds seen. default = 10)
#             --history-window ${window} \  

# # change the prompt used (defaults to system_prompt.txt)
#             --system-prompt my_custom_prompt.txt

# # change the reflection template used (defaults to reflection_prompt_template.txt)
#             --reflection-template my_reflection.txt

# # Preset reflection verbosity: minimal | standard | detailed (default: standard)
#             --reflection-type detailed

# #  specify server hostname for each agent
# #  possible hosts: nickel, zinc, copper, iron, tungsten 
# #  (defaults to tungsten as of 2/24/2026)
#             --host-0 ${HOST_0} \
#             --host-1 ${HOST_1} \

# #  specify LLM model for each agent
#             --model-0 "${MODEL_0}" \
#             --model-1 "${MODEL_1}" \



#             --output ${results_dir}/${run_name}.json \
##  outputs results to specified run directory using the specified name

# > ${results_dir}/${run_name}.log 2>&1
##   redirects output and errors to specified directory and file name
####################################################

##usage
# ./runIPD.sh    ## this runs the experiment in the background with nohup
# ./runIPD.sh -f ## this outputs the experiment to the terminal

# Parse arguments
follow=false
while getopts "f" opt; do
  case $opt in
    f) follow=true ;;
    *) echo "Usage: $0 [-f]"; exit 1 ;;
  esac
done

# Stop the script if anything errors
set -e
# Print each command as it runs (good for debugging)
set -x

results_dir="./results"
run_name="episodic_game_$(date +%Y%m%d_%H%M%S)"
episodes=10
rounds=10
window=20

# Define the python command once
CMD="python episodic_ipd_game.py \
    --no-reset \
    --episodes ${episodes} \
    --rounds ${rounds} \
    --history-window ${window} \
    --output ${results_dir}/${run_name}.json"

if [ "$follow" = true ]; then
    # Run in foreground and tail the log until the process finishes
    touch ${results_dir}/${run_name}.log
    $CMD > ${results_dir}/${run_name}.log 2>&1 &
    PID=$!
    tail -f ${results_dir}/${run_name}.log &
    TAIL_PID=$!
    wait $PID
    kill $TAIL_PID
else
    # Run in background with nohup
    nohup $CMD > ${results_dir}/${run_name}.log 2>&1 &
fi

