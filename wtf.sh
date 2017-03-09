# WTF: a terminal based Jira client.
# By Ryan Gaus.

EDITOR="${EDITOR:-${VISUAL:-vi}}" # How to edit config file
CONFIG_FILE_LOCATION="$HOME/.wtf-todo.config.json" # Where is the config file?

# If config file doesn't exist, make it and let the user input their username and password.
if [ ! -f "$CONFIG_FILE_LOCATION" ]; then
  echo '{
    "username": "ENTER YOUR JIRA USERNAME HERE",
    "password": "ENTER YOUR JIRA PASSWORD HERE",
    "basename": "ENTER THE URL OF YOUR JIRA INSTANCE, WITHOUT A TRAILING SLASH"
  }' > $CONFIG_FILE_LOCATION

  # Open editor so user can update it.
  $EDITOR $CONFIG_FILE_LOCATION
  echo "Config file saved in $CONFIG_FILE_LOCATION. Feel free to edit later."
fi

# Read options from config file
USERNAME="$(cat $CONFIG_FILE_LOCATION | jq .username | sed 's/"//g')"
PASSWORD="$(cat $CONFIG_FILE_LOCATION | jq .password | sed 's/"//g')"
BASENAME="$(cat $CONFIG_FILE_LOCATION | jq .basename | sed 's/"//g')"
AUTH="-u $USERNAME:$PASSWORD"

# Given an task id and a state, transition the given task to that state.
function move_task_to_state {
  local task_id="$1"
  local state="$2"

  # Pull down all states
  local transitions=$(curl --silent $AUTH \
    -H "Content-Type: application/json" \
    "$BASENAME/rest/api/2/issue/$task_id/transitions"
  )

  # Find the id of the state to move the given item to
  local transition_id=$(echo $transitions |
    jq ".transitions[] | select(.name | contains(\"$state\")) | .id" |
    sed 's/"//g'
  )

  echo "Transition item $task_id to $state ($transition_id)"

  # Transition issue to new state
  curl $AUTH -X POST \
    --data "{\"transition\": {\"id\": $transition_id}}" \
    -H "Content-Type: application/json" \
    "$BASENAME/rest/api/2/issue/$task_id/transitions?expand=transitions.fields"
}

case "$1" in
  # Show all tasks to work on
  # ie, `wtf todo`
  ""|todo|ls|list)
    DATA="$(
      curl --silent $AUTH \
      -H 'Content-Type: application/json' \
      "$BASENAME/rest/api/2/search?jql=assignee=$USERNAME")"

      echo "WTF todo?"
      echo
      echo "$(tput setaf 4)PRIOR   ID       STATUS$(tput sgr0)"
      echo $DATA | jq -r '
      .issues
      | to_entries
      | map({
        summary: .value.fields.summary,
        priority: .value.fields.priority.name,
        priority_id: .value.fields.priority.id,
        id: .key | tostring,
        key: .value.key,
        status: .value.fields.status.name
      })
      | sort_by(.priority_id)
      | map([.priority, .key, .status, .summary] | join(" | "))
      | join("\n")
      '
    ;;

  # Show info for a given task.
  # ie, `wtf into EMB-60`
  i|info)
    DATA="$(
      curl --silent $AUTH \
      -H 'Content-Type: application/json' \
      "$BASENAME/rest/api/2/issue/$2")"

    TITLE=$(echo $DATA | jq .fields.summary | sed 's/"//g')
    PROJECT=$(echo $DATA | jq .fields.project.key | sed 's/"//g')
    CREATOR=$(echo $DATA | jq .fields.creator.name | sed 's/"//g')
    REPORTER=$(echo $DATA | jq .fields.reporter.name | sed 's/"//g')
    PRIORITY=$(echo $DATA | jq .fields.priority.name | sed 's/"//g')
    STATUS=$(echo $DATA | jq .fields.status.name | sed 's/"//g')

    echo
    echo "$(tput setaf 3)* $TITLE$(tput sgr0)"
    echo
    echo "Link: $(tput setaf 6)$BASENAME/browse/$2$(tput sgr0)"
    echo "Status: $STATUS"
    echo "Project: $PROJECT"
    echo "Creator: $CREATOR"
    echo "Reporter: $REPORTER"
    echo "Priority: $PRIORITY"
    ;;

  # Move a given task to another state.
  u|undo)
    move_task_to_state $2 "To Do"
    ;;
  s|start)
    move_task_to_state $2 "In Progress"
    ;;
  d|"done"|finish)
    move_task_to_state $2 "QA"
    ;;

  # Open a task in the web browser
  o|open)
    if which open > /dev/null; then
      open $BASENAME/browse/$2
    elif which xdg-open > /dev/null; then
      xdg-open $BASENAME/browse/$2
    else
      echo "Can't find either open or xdg-open, please install one!"
    fi
    ;;

  # Help information
  h|help)
    echo "USAGE: wtf [SUBCOMMAND] [ID]"
    echo
    echo "wtf todo - get a list of all tasks assigned to you."
    echo "wtf info ID - get task info"
    echo "wtf open ID - open task ID in the browser"
    echo "wtf start ID - start working on task ID"
    echo "wtf done ID - finish working on task ID"
    echo
    echo "More info: https://github.com/1egoman/wtf-todo"
    ;;
  *)
    echo "WTF - a tool to tell you what to work on today." >&2
    echo "No such subcommand \`$1\` - try running \`$(basename $0) help\`" >&2
    exit 1
    ;;
esac


# curl $AUTH https://jira.density.io/rest/api/2/issue/EMB-30
