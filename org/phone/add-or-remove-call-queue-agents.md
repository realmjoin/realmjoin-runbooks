## How it works

A call queue gets its agents in exactly one of three ways, and the way is chosen in the Teams admin
center under "Call answering":

- **Users and groups** - agents are assigned individually, through groups, or both. This is the only
  mode the runbook changes. It adds the selected users to the list of individually assigned agents or
  takes them off it, and leaves the assigned groups exactly as they are.
- **A team and channel** - every member of that channel's team is an agent. The runbook prints the team
  and channel and stops without a change, because membership is managed in the team.
- **A shifts schedule** - agents come from a scheduling group in the Shifts app. The runbook prints the
  team behind the schedule and stops without a change.

Before anything is written, the runbook lists the current agents and checks every selected user. Users
that cannot become an agent are skipped with the reason, and the remaining ones are still processed.
Adding a user who is already an agent, or removing a user who is not one, is reported as "No action
taken" and changes nothing.

Two situations stop the run before any change is made: the queue would end up with more than 20
individually assigned agents, or a removal would leave the queue with no agents and no groups at all. In
the second case, keep one agent or assign a group or team to the queue in the Teams admin center first.

After the change the runbook reads the call queue back and compares the agent list with what was
requested. A mismatch is reported as a warning so it can be checked in the Teams admin center.

## Requirements for agents

- An agent needs a Teams Phone license with Enterprise Voice enabled. Users without it are skipped with
  that reason; set up Teams Phone for them and run the runbook again.
- Agents who take calls in the Teams app must be in TeamsOnly upgrade mode. Another mode is reported as a
  warning, and the user is still added.
- Only regular user accounts can be agents. Resource accounts and guests are skipped.
- Microsoft allows 20 individually assigned agents per call queue, and up to 200 agents when they come
  through groups. Use a group for larger teams.
- License and policy changes need time to reach the Teams service. After a new Teams Phone license it can
  take about an hour before a user can be assigned as an agent.
- A user who becomes an agent through a group can take up to eight hours before the queue offers the
  first call.

## Notes and limitations

- The runbook never changes the membership of a group or a team. A queue that gets its agents from a
  group, a team channel or a shifts schedule is reported with the place where its members are managed.
- Queues that mix individually assigned users with groups are supported. Only the individual assignments
  are changed; the groups stay untouched and their members are still agents.
- The agent list of a call queue is the service's own expansion of users and group members, and it is
  cached. A user who was just added to one of the assigned groups can still be reported as not being an
  agent, and a user removed from a group can still be listed for a while.
- Clearing the agent list completely is not possible here on purpose. Removing the last agent of a queue
  without groups is refused, because a queue without agents cannot take calls. Do that in the Teams admin
  center if it is really intended.
- Group, team and channel names come from Microsoft Graph. Without the optional permissions for it, the
  runbook prints the object IDs instead and works exactly the same.
