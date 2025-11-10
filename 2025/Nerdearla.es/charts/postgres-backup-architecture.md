# PostgreSQL Backup Architecture with pgBackRest and S3

Comprehensive backup and recovery architecture using pgBackRest with S3 storage.

## Backup Architecture Overview

```mermaid
graph TB
    subgraph "Patroni Cluster"
        PRIMARY["Patroni Primary<br/>PostgreSQL<br/>Active Writes"]
        REPLICA1["Patroni Replica 1<br/>PostgreSQL<br/>Read Only"]
        REPLICA2["Patroni Replica 2<br/>PostgreSQL<br/>Read Only"]
    end

    subgraph "pgBackRest Repository Server"
        PGBR[pgBackRest Process<br/>Backup Orchestration]
        PGBR_REPO[Local Repository<br/>Cache/Staging]
    end

    subgraph "S3 Storage"
        S3_WAL[S3 Bucket<br/>WAL Archive<br/>wal/]
        S3_BACKUP[S3 Bucket<br/>Backups<br/>backup/]
        S3_FULL[Full Backups<br/>Complete DB Copy]
        S3_INCR[Incremental Backups<br/>Changed Pages Since Last]
        S3_DIFF[Differential Backups<br/>Changed Since Last Full]
    end

    subgraph "Backup Operations"
        FULL_CMD[pgbackrest backup<br/>--type=full]
        INCR_CMD[pgbackrest backup<br/>--type=incr]
        DIFF_CMD[pgbackrest backup<br/>--type=diff]
    end

    %% WAL Archiving Flow
    PRIMARY -->|"1. Write WAL<br/>pg_wal/"| PRIMARY
    PRIMARY -->|"2. archive_command<br/>Continuous"| PGBR
    PGBR -->|"3. Push WAL"| PGBR_REPO
    PGBR_REPO -->|"4. Upload WAL<br/>Async"| S3_WAL

    %% Backup Flows
    FULL_CMD -->|Execute| PGBR
    INCR_CMD -->|Execute| PGBR
    DIFF_CMD -->|Execute| PGBR

    PGBR -->|"Read Data<br/>(via pg_basebackup<br/>or direct)"| PRIMARY
    PGBR -.->|"Alternative:<br/>Backup from Replica<br/>(reduce load)"| REPLICA1

    PGBR -->|Stage Locally| PGBR_REPO
    PGBR_REPO -->|Upload| S3_BACKUP

    S3_BACKUP --> S3_FULL
    S3_BACKUP --> S3_INCR
    S3_BACKUP --> S3_DIFF

    %% Replication
    PRIMARY -.->|Streaming<br/>Replication| REPLICA1
    PRIMARY -.->|Streaming<br/>Replication| REPLICA2

    style PRIMARY fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style REPLICA1 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style REPLICA2 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PGBR fill:#e67e22,stroke:#ca6f1e,stroke-width:3px
    style S3_WAL fill:#f39c12,stroke:#d68910,stroke-width:2px
    style S3_BACKUP fill:#f39c12,stroke:#d68910,stroke-width:2px
    style S3_FULL fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style S3_INCR fill:#9b59b6,stroke:#8e44ad,stroke-width:2px
    style S3_DIFF fill:#3498db,stroke:#2980b9,stroke-width:2px
```

## Backup Flow Details

### WAL Archiving Process

```mermaid
sequenceDiagram
    participant PG as PostgreSQL Primary
    participant ARCH as archive_command
    participant PBR as pgBackRest
    participant CACHE as Local Cache
    participant S3 as S3 Storage

    Note over PG: Transaction committed
    PG->>PG: Write to WAL segment
    PG->>PG: WAL segment full (16MB)
    PG->>ARCH: Trigger archive_command
    ARCH->>PBR: pgbackrest archive-push<br/>000000010000000000000001
    PBR->>PBR: Compress WAL file
    PBR->>CACHE: Stage compressed WAL
    PBR->>S3: Upload to wal/ prefix
    S3-->>PBR: Upload confirmed
    PBR-->>ARCH: Success
    ARCH-->>PG: Archive complete
    Note over PG: Safe to recycle WAL
```

## Backup Types and Schedule

```mermaid
gantt
    title Typical pgBackRest Backup Schedule
    dateFormat YYYY-MM-DD
    axisFormat %a %d

    section Full Backups
    Full Backup Week 1    :milestone, full1, 2024-01-07, 0d
    Full Backup Week 2    :milestone, full2, 2024-01-14, 0d
    Full Backup Week 3    :milestone, full3, 2024-01-21, 0d
    Full Backup Week 4    :milestone, full4, 2024-01-28, 0d

    section Differential Backups
    Diff Mon-Fri W1       :diff, 2024-01-08, 5d
    Diff Mon-Fri W2       :diff, 2024-01-15, 5d
    Diff Mon-Fri W3       :diff, 2024-01-22, 5d
    Diff Mon-Fri W4       :diff, 2024-01-29, 5d

    section Incremental Backups
    Incremental W1        :incr, 2024-01-08, 5d
    Incremental W2        :incr, 2024-01-15, 5d
    Incremental W3        :incr, 2024-01-22, 5d
    Incremental W4        :incr, 2024-01-29, 5d

    section Retention
    Retention Period      :active, 2024-01-07, 30d
```

## Backup Type Comparison

```mermaid
graph LR
    subgraph "Backup Types"
        FULL["Full Backup<br/>├─ Complete database copy<br/>├─ Size: 100GB<br/>├─ Time: 2 hours<br/>└─ Frequency: Weekly"]

        DIFF["Differential Backup<br/>├─ Changes since last FULL<br/>├─ Size: Growing (5-50GB)<br/>├─ Time: 30-60 min<br/>└─ Frequency: Daily"]

        INCR["Incremental Backup<br/>├─ Changes since last backup<br/>├─ Size: Consistent (2-5GB)<br/>├─ Time: 5-15 min<br/>└─ Frequency: Every 6 hours"]
    end

    subgraph "Recovery Dependencies"
        FULL_REC[Full Backup]
        DIFF_REC[Differential Backup]
        INCR_REC1[Incremental 1]
        INCR_REC2[Incremental 2]
        INCR_REC3[Incremental 3]
        WAL_REC[WAL Files]
    end

    FULL -->|Base for| DIFF
    FULL -->|Base for| INCR
    DIFF -->|References| FULL
    INCR -->|Chain of| INCR

    FULL_REC --> DIFF_REC
    DIFF_REC --> WAL_REC

    FULL_REC --> INCR_REC1
    INCR_REC1 --> INCR_REC2
    INCR_REC2 --> INCR_REC3
    INCR_REC3 --> WAL_REC

    style FULL fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style DIFF fill:#3498db,stroke:#2980b9,stroke-width:2px
    style INCR fill:#9b59b6,stroke:#8e44ad,stroke-width:2px
```

## Recovery Scenarios

### Point-in-Time Recovery (PITR)

```mermaid
sequenceDiagram
    participant ADMIN as Administrator
    participant PBR as pgBackRest
    participant S3 as S3 Storage
    participant PG as PostgreSQL (New)
    participant DCS as DCS (etcd)

    ADMIN->>PBR: pgbackrest restore<br/>--type=time<br/>--target="2024-01-15 14:30:00"
    PBR->>S3: Download latest full backup
    S3-->>PBR: Base backup data
    PBR->>S3: Download required incrementals/diffs
    S3-->>PBR: Incremental data
    PBR->>PG: Restore base + incrementals
    PBR->>S3: Download WAL files
    S3-->>PBR: WAL archives
    PBR->>PG: Place WAL in pg_wal/
    PBR->>PG: Create recovery.signal
    PBR->>PG: Set recovery_target_time
    ADMIN->>PG: Start PostgreSQL
    PG->>PG: Replay WAL to target time
    PG->>PG: Recovery complete
    PG-->>ADMIN: Database ready
    ADMIN->>DCS: Update Patroni config
    DCS->>PG: Health checks
    Note over PG: Cluster operational
```

### Disaster Recovery - Full Restore

```mermaid
sequenceDiagram
    participant ADMIN as Administrator
    participant PBR as pgBackRest
    participant S3 as S3 Storage
    participant NEW as New PostgreSQL Cluster
    participant PAT as Patroni

    Note over ADMIN: Disaster scenario:<br/>Complete cluster loss

    ADMIN->>PBR: pgbackrest restore<br/>--type=immediate<br/>--target-action=promote

    PBR->>S3: Download latest full backup
    S3-->>PBR: Full backup (100GB)

    PBR->>S3: Download latest differential
    S3-->>PBR: Differential backup (20GB)

    PBR->>S3: Download incrementals
    S3-->>PBR: Incremental backups (5GB each)

    PBR->>NEW: Extract and restore data

    PBR->>S3: Download all WAL since backup
    S3-->>PBR: WAL archives

    PBR->>NEW: Configure recovery

    ADMIN->>NEW: Start PostgreSQL
    NEW->>NEW: Apply backups + WAL
    NEW->>NEW: Promote to primary
    NEW-->>ADMIN: Database online

    ADMIN->>PAT: Initialize Patroni cluster
    PAT->>NEW: Register as primary

    Note over NEW: Build new replicas<br/>from primary
```

## S3 Storage Structure

```mermaid
graph TB
    subgraph "S3 Bucket: pg-backups"
        ROOT["/"]

        subgraph "Archive Location"
            ARCHIVE["archive/<br/>stanza-name/"]
            ARCH_VER["16-1/"]
            WAL_FILES["WAL Files<br/>000000010000000000000001.gz<br/>000000010000000000000002.gz<br/>..."]
        end

        subgraph "Backup Location"
            BACKUP["backup/<br/>stanza-name/"]
            BCK_INFO["backup.info<br/>backup.info.copy"]

            FULL_BCK["20240107-120000F/<br/>(Full Backup)<br/>├─ backup.manifest<br/>├─ pg_data.tar.gz<br/>└─ Size: 100GB"]

            DIFF_BCK["20240108-120000F_20240114-120000D/<br/>(Differential)<br/>├─ backup.manifest<br/>├─ pg_data_delta.tar.gz<br/>└─ Size: 20GB"]

            INCR_BCK["20240108-120000F_20240115-000000I/<br/>(Incremental)<br/>├─ backup.manifest<br/>├─ pg_data_delta.tar.gz<br/>└─ Size: 5GB"]
        end

        subgraph "Latest Symlinks"
            LATEST["latest/"]
            LATEST_FULL["latest-full → 20240107-120000F"]
            LATEST_DIFF["latest-diff → 20240114-120000D"]
            LATEST_INCR["latest-incr → 20240115-000000I"]
        end
    end

    ROOT --> ARCHIVE
    ROOT --> BACKUP
    ROOT --> LATEST

    ARCHIVE --> ARCH_VER
    ARCH_VER --> WAL_FILES

    BACKUP --> BCK_INFO
    BACKUP --> FULL_BCK
    BACKUP --> DIFF_BCK
    BACKUP --> INCR_BCK

    LATEST --> LATEST_FULL
    LATEST --> LATEST_DIFF
    LATEST --> LATEST_INCR

    style ROOT fill:#f39c12,stroke:#d68910,stroke-width:3px
    style ARCHIVE fill:#3498db,stroke:#2980b9,stroke-width:2px
    style BACKUP fill:#2ecc71,stroke:#27ae60,stroke-width:2px
    style FULL_BCK fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style DIFF_BCK fill:#3498db,stroke:#2980b9,stroke-width:2px
    style INCR_BCK fill:#9b59b6,stroke:#8e44ad,stroke-width:2px
```

## Key Features

### Backup Strategy Benefits

1. **Full Backup (Weekly)**
   - Complete database snapshot
   - Independent restore point
   - Baseline for differential/incremental

2. **Differential Backup (Daily)**
   - Changes since last full
   - Faster than full backup
   - Quick restore (only need full + latest diff)

3. **Incremental Backup (Every 6 hours)**
   - Smallest backup size
   - Minimal impact on production
   - Requires full chain for restore

### Recovery Capabilities

- **Point-in-Time Recovery (PITR)**: Restore to any moment
- **Parallel Restore**: Fast recovery with multiple processes
- **Delta Restore**: Only restore changed files
- **Tablespace Remapping**: Flexible restore paths
- **Backup from Replica**: Zero impact on primary

### High Availability Features

- **S3 Durability**: 99.999999999% durability
- **Multi-Region Support**: Cross-region replication
- **Encryption**: At-rest and in-transit
- **Compression**: Reduced storage costs
- **Retention Policies**: Automatic cleanup
