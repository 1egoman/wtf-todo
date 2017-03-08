
BASENAME="https://jira.density.io"

AUTH="-u ryan:foo"

QUERY="assignee=ryan"

case "$1" in
  todo)
    DATA="$(
      curl --silent $AUTH \
      -H 'Content-Type: application/json' \
      "$BASENAME/rest/api/2/search?jql=$QUERY")"

      echo $DATA | jq -r '
      .issues
      | map({summary: .fields.summary, id: .key, status: .fields.status.name})
      | sort_by(.status)
      | map([.id, .status, .summary] | join(" | "))
      | join("\n")
      '
    ;;
esac
