# Dockge migration

 I want to try out dockge for docker compose sack management. Im currently using portainer, which is deployed with ansible and managed with stack-sync. This is going to be a multi-stage migration, with many breaks for manual testing and re-evaluation.


- [x] Phase 1: Deploy dockge
- [x] Phase 2: Test sample stack with dockge UI
- [ ] Phase 3: Update stack-sync to use SSH deployment
- [ ] Phase 4: Test SSH deployment, verify functionality in dockge UI
- [ ] Phase 5: Migrate stacks from portainer to Dockge, verify all stacks work.
- [ ] Phase 6: Add ansible role to configure dockge on fresh docker host deploy (alternative to portainer)
- [ ] Phase 7: Test end-to-end setup: new docker host, install dockge, bring up stacks

## Phase 1

Deploying Dockge will initially be done with stack sync, with a compose file in `apps/`. The trick here is mapping the compose directory to the /`tank/apps/` directory where backup is already automated. Dockge has strict requirements on the stack directory mount.

## Phase 2

This is entirely manual

