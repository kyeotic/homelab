## ZFS on Proxmox Directly

Create or import the zfs pool. [This video](https://www.youtube.com/watch?v=oSD-VoloQag) can with creation.


Most recently used this for creation

```
zpool create -o 'ashift=12' -f tank raidz /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105328K /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105404L /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105332H /dev/disk/by-id/ata-TEAM_T2532TB_TPBF2308210040501232
```

# Datasets

```
zfs create tank/nas
zfs create tank/media_root
zfs create tank/apps
```