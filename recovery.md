# Homelab Pool Loss Recovery

This was a catastrophic, yet avoidable, loss of time and effort. The pool had no backup, so all apps running lost their configuration; losing their setup and personalization.

The plan to avoid this in the future is

1. Backup all app configuration to the
   1.  OS HDD (it should fit, even with large apps)
   2.  Your gaming computer
2.  Backup the PBS to
    1.  The Pool
    2.  Your Gaming Computer
3. Create a cloud VM (or schedule task, e.g. docker, deno?!) that runs and stores a
   1. PBS Backup
   2. App configuration
   3. https://rsync.net/pricing.html could be an alternative

Once all these are done, run the following tests to ensure preparedness. First,  a VM first, so that the real OS or pool are not lost, and second on the actual server.
  - [ ] Deleting the pool and restoring from
    - [ ] OS HDD app config backup
    - [ ] a cloud backup
  - [ ] Reinstalling Proxmox with a fresh install from the
    - [ ] pool backup
    - [ ] gaming backup
    - [ ] cloud backup
  - [ ] Formatting a disk and resilvering with ZFS

If possible, include, in all these backups, which servarr collections you were subscribed to, so that externally available sources can refill the part of the pool that you aren't backing up: media content.

The ultimate goal is to ensure all data that cannot be downloaded from HA available sources, like usenet or linux iso repositories, is backed up to two internal sources and one external source. The 3:2:1 rule. You should be past these kinds of failures. Be prepared.

## Cloud Backup Pricing

| Provider     | Cost/Tb |
| ------------ | ------- |
| Backblaze b2 | 6       |
| Borg Base    | 6       |
| Rsync        | 9       |


Borgbase backup repo: `rest:https://sd9j6dod:X23NkZv6sobxuAND@sd9j6dod.repo.borgbase.com`
Restic password is in the Borgbase Bitwarden Vault