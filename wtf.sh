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
USERNAME="$(cat $CONFIG_FILE_LOCATION | jq -r .username)"
PASSWORD="$(cat $CONFIG_FILE_LOCATION | jq -r .password)"
BASENAME="$(cat $CONFIG_FILE_LOCATION | jq -r .basename)"
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
    jq -r ".transitions[] | select(.name | contains(\"$state\")) | .id"
  )

  echo "Transition item $task_id to $state ($transition_id)"

  # Transition issue to new state
  curl $AUTH -X POST \
    --data "{\"transition\": {\"id\": $transition_id}}" \
    -H "Content-Type: application/json" \
    "$BASENAME/rest/api/2/issue/$task_id/transitions?expand=transitions.fields"
}

function start_load {
  if [[ -z "$1" ]]; then
    printf "Loading... "
  else
    printf "$1..."
  fi
}

function finish_load {
  ceol="$(tput el)" # terminfo clr_eol
  echo -ne "\r$ceol"
}

case "$1" in
  # Show all tasks to work on
  # ie, `wtf todo`
  ""|todo|ls|list)
    start_load "Loading Tasks"
    DATA="$(
      curl --silent $AUTH \
      -H 'Content-Type: application/json' \
      "$BASENAME/rest/api/2/search?jql=assignee=$USERNAME")"
    finish_load

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
    start_load "Loading Task"
    DATA="$(
      curl --silent $AUTH \
      -H 'Content-Type: application/json' \
      "$BASENAME/rest/api/2/issue/$2")"
    finish_load

    TITLE=$(echo $DATA | jq -r .fields.summary)
    PROJECT=$(echo $DATA | jq -r .fields.project.key)
    CREATOR=$(echo $DATA | jq -r .fields.creator.name)
    REPORTER=$(echo $DATA | jq -r .fields.reporter.name)
    PRIORITY=$(echo $DATA | jq -r .fields.priority.name)
    STATUS=$(echo $DATA | jq -r .fields.status.name)

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

  c|create)
    start_load "Loading all projects"
    PROJECTS="$(
      curl --silent $AUTH \
      -H 'Content-Type: application/json' \
      "$BASENAME/rest/api/2/issue/createmeta")"
    finish_load

    echo $PROJECTS |
      jq -r '.projects | map([.key, .name] | join(" ")) | join("\n")' |
      nl -v 0
    printf "Create issue in project: "; read proj_id
    # if ! [[ "$proj_id" =~ '^[0-9]*$' ]]; then
    #   echo "Didn't enter project index!" >&2
    #   exit 1
    # fi

    PROJECT="$(echo $PROJECTS | jq .projects[$proj_id])"

    echo $PROJECT |
      jq -r '.issuetypes | map(.name) | join("\n")' |
      nl -v 0
    printf "Issue Type: "; read type_id
    # if ! [[ "$type_id" =~ '^[0-9]*$' ]]; then
    #   echo "Didn't enter issue type index!" >&2
    #   exit 1
    # fi
    ISSUE_TYPE="$(echo $PROJECT | jq -r ".issuetypes[$type_id].id")"

    printf "Issue Summary: "; read name
    printf "Issue Description: "; read desc

    PRIORITIES='["Major", "Minor", "Critical", "Blocker", "Trivial"]'
    echo $PRIORITIES | jq -r '. | join("\n")' | nl -v 0
    printf "Issue Priority: "; read priority_id
    # if ! [[ "$priority_id" =~ '^[0-9]*$' ]]; then
    #   echo "Didn't enter priority index!" >&2
    #   exit 1
    # fi
    PRIORITY="$(echo $PRIORITIES | jq -r ".[$priority_id]")"

    echo "{
    \"fields\": {
      \"project\": { 
        \"id\": \"$(echo $PROJECT | jq -r '.id')\"
      },
      \"summary\": \"$name\",
      \"description\": \"$desc\",
      \"issuetype\": {
        \"id\": \"$ISSUE_TYPE\"
      },
      \"priority\": {
        \"name\": \"$PRIORITY\"
      }
   }
}"
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
