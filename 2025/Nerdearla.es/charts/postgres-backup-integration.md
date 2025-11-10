# Patroni + pgBackRest Integration

How pgBackRest integrates with Patroni for automated backup management.

## Patroni Configuration with pgBackRest

```mermaid
graph TB
    subgraph "Patroni Cluster with Backup Integration"
        subgraph "Primary Node"
            PAT_PRI[Patroni Primary]
            PG_PRI[PostgreSQL Primary]
            PGBR_PRI[pgBackRest Client]
        end

        subgraph "Replica Node 1"
            PAT_REP1[Patroni Replica 1]
            PG_REP1[PostgreSQL Replica]
            PGBR_REP1[pgBackRest Client]
        end

        subgraph "Replica Node 2"
            PAT_REP2[Patroni Replica 2]
            PG_REP2[PostgreSQL Replica]
            PGBR_REP2[pgBackRest Client]
        end
    end

    subgraph "Backup Infrastructure"
        PGBR_SRV[pgBackRest Repository Server<br/>Dedicated Host]
        CRON[Cron/Scheduler<br/>Backup Jobs]
    end

    subgraph "Storage"
        S3[S3 Storage<br/>WAL + Backups]
    end

    subgraph "DCS"
        ETCD[(etcd Cluster)]
    end

    %% Patroni to PostgreSQL
    PAT_PRI --> PG_PRI
    PAT_REP1 --> PG_REP1
    PAT_REP2 --> PG_REP2

    %% PostgreSQL to pgBackRest clients
    PG_PRI --> PGBR_PRI
    PG_REP1 --> PGBR_REP1
    PG_REP2 --> PGBR_REP2

    %% WAL Archiving
    PGBR_PRI -->|archive_command<br/>Push WAL| S3

    %% Backup operations
    CRON -->|Trigger Backups| PGBR_SRV
    PGBR_SRV -->|SSH/TLS<br/>Read Data| PG_REP1
    PGBR_SRV -.->|Alternative<br/>Backup Source| PG_PRI
    PGBR_SRV -->|Store Backups| S3

    %% Patroni DCS
    PAT_PRI <--> ETCD
    PAT_REP1 <--> ETCD
    PAT_REP2 <--> ETCD

    %% Replication
    PG_PRI -.->|Streaming<br/>Replication| PG_REP1
    PG_PRI -.->|Streaming<br/>Replication| PG_REP2

    %% WAL Restore (for replicas)
    S3 -.->|restore_command<br/>Pull WAL if needed| PGBR_REP1
    S3 -.->|restore_command<br/>Pull WAL if needed| PGBR_REP2

    style PAT_PRI fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style PG_PRI fill:#2ecc71,stroke:#27ae60,stroke-width:2px
    style PAT_REP1 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PAT_REP2 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PGBR_SRV fill:#e67e22,stroke:#ca6f1e,stroke-width:3px
    style S3 fill:#f39c12,stroke:#d68910,stroke-width:2px
    style ETCD fill:#e74c3c,stroke:#c0392b,stroke-width:2px
```

## Backup Workflow with Patroni

```mermaid
sequenceDiagram
    participant CRON as Cron Scheduler
    participant PBR as pgBackRest Server
    participant PAT as Patroni (Replica)
    participant PG as PostgreSQL (Replica)
    participant S3 as S3 Storage
    participant PRIM as PostgreSQL (Primary)

    Note over CRON: Daily backup scheduled<br/>2:00 AM

    CRON->>PBR: Execute backup command<br/>pgbackrest backup --type=diff

    PBR->>PAT: Query cluster status
    PAT-->>PBR: Replica healthy, in-sync

    Note over PBR: Choose replica to minimize<br/>primary impact

    PBR->>PG: Start backup<br/>(pg_start_backup via replication slot)
    PG-->>PBR: Backup started

    PBR->>PG: Copy changed data blocks<br/>(parallel streams)
    PG-->>PBR: Data transfer (streaming)

    PBR->>PG: Finish backup<br/>(pg_stop_backup)
    PG-->>PBR: Backup completed

    PBR->>PBR: Compress backup data
    PBR->>PBR: Verify backup integrity

    PBR->>S3: Upload backup<br/>(parallel upload)
    S3-->>PBR: Upload complete

    PBR->>S3: Update backup metadata
    S3-->>PBR: Metadata updated

    PBR-->>CRON: Backup successful

    Note over PBR,S3: Backup available for<br/>restore operations
```

## Failover Scenario with Backup Integration

```mermaid
sequenceDiagram
    participant PRI as Primary PostgreSQL
    participant REP as Replica PostgreSQL
    participant PAT_PRI as Patroni (Primary)
    participant PAT_REP as Patroni (Replica)
    participant ETCD as etcd
    participant S3 as S3 (WAL Archive)

    Note over PRI: Primary node fails

    PRI->>PRI: Node crash
    PAT_PRI->>ETCD: Heartbeat lost

    Note over ETCD: Primary key TTL expires

    PAT_REP->>ETCD: Detect primary failure
    ETCD->>PAT_REP: No primary leader

    PAT_REP->>PAT_REP: Start leader election
    PAT_REP->>ETCD: Attempt to acquire lock
    ETCD-->>PAT_REP: Lock acquired

    Note over PAT_REP: Elected as new primary

    PAT_REP->>REP: Check replication lag
    REP-->>PAT_REP: Lag minimal

    PAT_REP->>S3: Check for any missing WAL
    S3-->>PAT_REP: WAL files available

    alt Missing WAL from old primary
        PAT_REP->>S3: Pull missing WAL segments
        S3-->>REP: Deliver WAL
        REP->>REP: Apply missing WAL
    end

    PAT_REP->>REP: Promote to primary<br/>(pg_promote)
    REP->>REP: Promotion in progress
    REP-->>PAT_REP: Promotion complete

    Note over REP: Now accepting writes

    PAT_REP->>ETCD: Update cluster state
    ETCD-->>PAT_REP: State updated

    REP->>S3: Start archiving WAL<br/>(archive_command active)

    Note over REP,S3: Continuous backup resumed<br/>with new primary
```

## Configuration Files

### Patroni Configuration (patroni.yml)

```mermaid
graph LR
    subgraph "patroni.yml Configuration"
        CONFIG["patroni.yml"]

        subgraph "PostgreSQL Parameters"
            ARCH_CMD["archive_mode: 'on'<br/>archive_command:<br/>'pgbackrest --stanza=main<br/>archive-push %p'"]

            REST_CMD["restore_command:<br/>'pgbackrest --stanza=main<br/>archive-get %f %p'"]

            ARCH_TIMEOUT["archive_timeout: '60s'"]
        end

        subgraph "Backup Settings"
            CREATE_SLOT["create_replica_methods:<br/>- pgbackrest<br/>- basebackup"]

            PGBR_METHOD["pgbackrest:<br/>command: pgbackrest<br/>--stanza=main<br/>--type=standby<br/>restore"]
        end
    end

    CONFIG --> ARCH_CMD
    CONFIG --> REST_CMD
    CONFIG --> ARCH_TIMEOUT
    CONFIG --> CREATE_SLOT
    CONFIG --> PGBR_METHOD

    style CONFIG fill:#e67e22,stroke:#ca6f1e,stroke-width:3px
    style ARCH_CMD fill:#2ecc71,stroke:#27ae60,stroke-width:2px
    style REST_CMD fill:#3498db,stroke:#2980b9,stroke-width:2px
```



## Backup Monitoring and Alerts

```mermaid
graph TB
    subgraph "Monitoring Components"
        PGBR[pgBackRest]

        subgraph "Metrics Exporters"
            SCRIPT[pgbackrest info<br/>--output=json]
            EXPORTER[Custom Exporter<br/>Parse JSON]
        end

        subgraph "Prometheus"
            PROM[Prometheus<br/>Time-Series DB]

            METRICS["Metrics:<br/>├─ Last backup age<br/>├─ Backup size<br/>├─ Backup duration<br/>├─ WAL archive lag<br/>├─ Failed backups<br/>└─ Repository size"]
        end

        subgraph "Alerting"
            ALERT["Alert Rules:<br/>├─ No backup > 24h<br/>├─ WAL archive lag > 10min<br/>├─ Backup failures<br/>├─ Repository > 80% full<br/>└─ Restore test failures"]
        end

        subgraph "Visualization"
            GRAF[Grafana Dashboard<br/>├─ Backup timeline<br/>├─ WAL archive rate<br/>├─ Storage usage<br/>└─ Recovery capability]
        end

        subgraph "Actions"
            PAGE[PagerDuty<br/>On-Call Alerts]
            SLACK[Slack Notifications]
        end
    end

    PGBR -->|info command| SCRIPT
    SCRIPT --> EXPORTER
    EXPORTER --> PROM
    PROM --> METRICS
    METRICS --> ALERT
    METRICS --> GRAF

    ALERT -->|Critical| PAGE
    ALERT -->|Warning| SLACK

    style PGBR fill:#e67e22,stroke:#ca6f1e,stroke-width:3px
    style PROM fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style GRAF fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PAGE fill:#e74c3c,stroke:#c0392b,stroke-width:2px
```

## Automated Restore Testing

```mermaid
sequenceDiagram
    participant CRON as Weekly Cron Job
    participant TEST as Test Server
    participant PBR as pgBackRest
    participant S3 as S3 Storage
    participant VERIFY as Verification Script
    participant ALERT as Alert System

    Note over CRON: Weekly restore test<br/>Saturday 3:00 AM

    CRON->>TEST: Provision clean test instance
    TEST->>PBR: pgbackrest restore<br/>--type=time<br/>--target=latest

    PBR->>S3: Download latest full backup
    S3-->>PBR: Backup data

    PBR->>S3: Download incrementals/diffs
    S3-->>PBR: Incremental data

    PBR->>TEST: Restore to test instance
    TEST->>TEST: Start PostgreSQL
    TEST->>TEST: Apply WAL to latest

    TEST-->>VERIFY: Database online

    VERIFY->>TEST: Run validation queries
    TEST-->>VERIFY: Query results

    VERIFY->>TEST: Check data integrity
    TEST-->>VERIFY: pg_checksums OK

    VERIFY->>TEST: Verify table counts
    TEST-->>VERIFY: Counts match

    VERIFY->>TEST: Check replication slots
    TEST-->>VERIFY: Slots valid

    alt Restore successful
        VERIFY->>ALERT: Send success notification
        ALERT->>ALERT: Log successful test
    else Restore failed
        VERIFY->>ALERT: Send critical alert
        ALERT->>ALERT: Page on-call engineer
    end

    VERIFY->>TEST: Shutdown and cleanup
    TEST->>TEST: Terminate instance

    Note over TEST: Test complete,<br/>restore capability verified
```

