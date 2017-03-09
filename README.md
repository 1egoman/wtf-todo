# WTF

A terminal based Jira client that's made to be customized for an organisation. Fork away!

```bash
$ wtf todo
WTF todo?

PRIOR   ID       STATUS
Minor | EMB-60 | In Progress | Magical Jellybeans
Minor | EMB-20 | In Progress | Magical Jellybeans
$ wtf info EMB-60

* Magical Jellybeans

Link: https://jira.example.com/browse/EMB-60
Status: In Progress
Project: EMB
Creator: beweinreich
Reporter: beweinreich
Priority: Minor
$ wtf start EMB-30
$ wtf finish EMB-30
$ wtf open EMB-30
# (opens in web browser)
```

## Customization
```bash
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
```

Here are a few examples of tasks that are in the script as-is. The function `move_task_to_state`
moves a task to a given state given a task id and a state name. Since state names can change per
organisation, the script needs to be modified to work with other organisations unless you copy the
names that I've hard-coded. Feel free to add more cases to the switch to customize your own version
of the tool.

## Installing
After cloning, symlink `wtf.sh` to `/usr/local/bin/wtf`.
