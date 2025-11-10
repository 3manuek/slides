# PostgreSQL Multi-Region Architecture with Patroni Standby Cluster

Comprehensive multi-region setup with primary region cluster and secondary region standby cluster for disaster recovery.

## Multi-Region Architecture Overview

```mermaid
graph TB
    subgraph "Primary Region - US-EAST-1"
        subgraph "Client Layer - Primary"
            APP_PRI[Application Servers<br/>Write + Read]
        end

        subgraph "Load Balancer - Primary"
            LB_PRI[Envoy/HAProxy<br/>Write: :5432<br/>Read: :5433]
        end

        subgraph "Patroni Primary Cluster"
            PAT_PRI_1["Patroni Node 1<br/>PRIMARY<br/>PostgreSQL Master<br/>Read/Write"]
            PAT_PRI_2["Patroni Node 2<br/>REPLICA<br/>PostgreSQL Standby<br/>Read Only"]
            PAT_PRI_3["Patroni Node 3<br/>REPLICA<br/>PostgreSQL Standby<br/>Read Only"]
        end

        subgraph "DCS - Primary Region"
            ETCD_PRI[(etcd Cluster<br/>US-EAST-1<br/>Primary Config)]
        end

        subgraph "Backup - Primary"
            PGBR_PRI[pgBackRest<br/>Primary Region]
        end
    end

    subgraph "Secondary Region - US-WEST-2"
        subgraph "Client Layer - Secondary"
            APP_SEC[Application Servers<br/>Read Only]
        end

        subgraph "Load Balancer - Secondary"
            LB_SEC[Envoy/HAProxy<br/>Read: :5433<br/>Write BLOCKED]
        end

        subgraph "Patroni STANDBY Cluster"
            PAT_SEC_1["Patroni Node 1<br/>STANDBY LEADER<br/>PostgreSQL Replica<br/>Read Only"]
            PAT_SEC_2["Patroni Node 2<br/>STANDBY REPLICA<br/>PostgreSQL Replica<br/>Read Only"]
            PAT_SEC_3["Patroni Node 3<br/>STANDBY REPLICA<br/>PostgreSQL Replica<br/>Read Only"]
        end

        subgraph "DCS - Secondary Region"
            ETCD_SEC[(etcd Cluster<br/>US-WEST-2<br/>Standby Config)]
        end

        subgraph "Backup - Secondary"
            PGBR_SEC[pgBackRest<br/>Secondary Region]
        end
    end

    subgraph "Cross-Region Storage"
        S3_GLOBAL[(S3 Multi-Region<br/>WAL Archive<br/>Backups<br/>Cross-Region Replication)]
    end

    subgraph "Global DNS/Routing"
        DNS[Route53/Global DNS<br/>Primary: db-primary.example.com<br/>Secondary: db-secondary.example.com]
    end

    %% Primary Region Connections
    DNS --> APP_PRI
    APP_PRI --> LB_PRI
    LB_PRI --> PAT_PRI_1
    LB_PRI --> PAT_PRI_2
    LB_PRI --> PAT_PRI_3

    PAT_PRI_1 <--> ETCD_PRI
    PAT_PRI_2 <--> ETCD_PRI
    PAT_PRI_3 <--> ETCD_PRI

    %% Primary Region Replication
    PAT_PRI_1 -.->|Streaming<br/>Replication| PAT_PRI_2
    PAT_PRI_1 -.->|Streaming<br/>Replication| PAT_PRI_3

    %% Secondary Region Connections
    DNS --> APP_SEC
    APP_SEC --> LB_SEC
    LB_SEC --> PAT_SEC_1
    LB_SEC --> PAT_SEC_2
    LB_SEC --> PAT_SEC_3

    PAT_SEC_1 <--> ETCD_SEC
    PAT_SEC_2 <--> ETCD_SEC
    PAT_SEC_3 <--> ETCD_SEC

    %% Secondary Region Replication (Cascading)
    PAT_SEC_1 -.->|Cascading<br/>Replication| PAT_SEC_2
    PAT_SEC_1 -.->|Cascading<br/>Replication| PAT_SEC_3

    %% Cross-Region Replication
    PAT_PRI_1 ==>|WAL Streaming<br/>OR<br/>WAL Shipping via S3| PAT_SEC_1

    %% Backup flows
    PAT_PRI_1 --> PGBR_PRI
    PGBR_PRI --> S3_GLOBAL
    PAT_SEC_1 --> PGBR_SEC
    PGBR_SEC --> S3_GLOBAL

    %% WAL Archive
    PAT_PRI_1 -->|Archive WAL| S3_GLOBAL
    PAT_SEC_1 -.->|Restore WAL| S3_GLOBAL

    style PAT_PRI_1 fill:#2ecc71,stroke:#27ae60,stroke-width:4px
    style PAT_PRI_2 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PAT_PRI_3 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PAT_SEC_1 fill:#9b59b6,stroke:#8e44ad,stroke-width:3px
    style PAT_SEC_2 fill:#8e44ad,stroke:#7d3c98,stroke-width:2px
    style PAT_SEC_3 fill:#8e44ad,stroke:#7d3c98,stroke-width:2px
    style ETCD_PRI fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style ETCD_SEC fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style S3_GLOBAL fill:#f39c12,stroke:#d68910,stroke-width:3px
```

## Patroni Configuration Differences

```mermaid
graph TB
    subgraph "Primary Region Configuration"
        PRI_CONFIG["patroni.yml (Primary Region)<br/>───────────────────────"]

        PRI_SCOPE["scope: postgres-cluster<br/>(Normal operational mode)"]

        PRI_STANDBY["standby_cluster:<br/>  NOT CONFIGURED<br/>  (Acts as normal cluster)"]

        PRI_BOOTSTRAP["bootstrap:<br/>  dcs:<br/>    postgresql:<br/>      parameters:<br/>        wal_level: replica<br/>        archive_mode: on"]
    end

    subgraph "Secondary Region Configuration"
        SEC_CONFIG["patroni.yml (Secondary Region)<br/>───────────────────────"]

        SEC_SCOPE["scope: postgres-cluster<br/>(Same scope name!)"]

        SEC_STANDBY["standby_cluster:<br/>  host: primary-leader.us-east-1<br/>  port: 5432<br/>  primary_slot_name: standby_cluster<br/>  create_replica_methods:<br/>    - basebackup<br/>  restore_command:<br/>    'pgbackrest archive-get %f %p'"]

        SEC_BOOTSTRAP["bootstrap:<br/>  method: standby_cluster<br/>  standby_cluster:<br/>    host: primary-leader.us-east-1<br/>    port: 5432"]
    end

    PRI_CONFIG --> PRI_SCOPE
    PRI_CONFIG --> PRI_STANDBY
    PRI_CONFIG --> PRI_BOOTSTRAP

    SEC_CONFIG --> SEC_SCOPE
    SEC_CONFIG --> SEC_STANDBY
    SEC_CONFIG --> SEC_BOOTSTRAP

    style PRI_CONFIG fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style SEC_CONFIG fill:#9b59b6,stroke:#8e44ad,stroke-width:3px
    style SEC_STANDBY fill:#e74c3c,stroke:#c0392b,stroke-width:2px
```

## Cross-Region Replication Methods

### Method 1: WAL Streaming (Recommended)

```mermaid
sequenceDiagram
    participant PRI as Primary Region<br/>Leader
    participant SLOT as Replication Slot<br/>'standby_cluster'
    participant NET as Cross-Region<br/>Network
    participant SEC as Secondary Region<br/>Standby Leader
    participant SEC_REP as Secondary<br/>Replicas

    Note over PRI: Transaction committed

    PRI->>PRI: Write to WAL
    PRI->>SLOT: Hold WAL in slot

    SEC->>NET: Request WAL stream
    NET->>PRI: Forward request
    PRI->>SLOT: Read WAL
    SLOT->>NET: Stream WAL data
    NET->>SEC: Deliver WAL (compressed)

    SEC->>SEC: Apply WAL changes
    SEC->>SEC: Make data available

    SEC-.->SEC_REP: Cascade replication
    SEC_REP-.->SEC_REP: Apply changes locally

    Note over SEC: Data replicated<br/>Lag: 100-500ms
```

### Method 2: WAL Shipping via S3

```mermaid
sequenceDiagram
    participant PRI as Primary Region<br/>Leader
    participant S3 as S3 Cross-Region<br/>Storage
    participant SEC as Secondary Region<br/>Standby Leader
    participant SEC_REP as Secondary<br/>Replicas

    Note over PRI: Transaction committed

    PRI->>PRI: Write to WAL segment
    PRI->>PRI: WAL segment complete (16MB)
    PRI->>S3: archive_command<br/>Upload WAL
    S3->>S3: Store in us-east-1
    S3->>S3: Cross-region replication<br/>to us-west-2

    Note over SEC: Check for new WAL<br/>(every 1-5 seconds)

    SEC->>S3: restore_command<br/>Request next WAL
    S3->>SEC: Download WAL from<br/>nearest region
    SEC->>SEC: Apply WAL changes

    SEC-.->SEC_REP: Cascade replication
    SEC_REP-.->SEC_REP: Apply changes

    Note over SEC: Data replicated<br/>Lag: 1-10 seconds
```

### Method 3: Hybrid (Streaming + S3 Fallback)

```mermaid
graph LR
    subgraph "Primary Region"
        PRI[Primary Leader]
    end

    subgraph "Cross-Region Links"
        STREAM[WAL Streaming<br/>Primary Method<br/>Low Latency]
        S3[S3 WAL Archive<br/>Fallback Method<br/>High Availability]
    end

    subgraph "Secondary Region"
        SEC[Standby Leader]
    end

    PRI -->|1. Stream WAL<br/>Real-time| STREAM
    STREAM -->|Normal Path| SEC

    PRI -->|2. Archive WAL<br/>Continuous| S3
    S3 -.->|Fallback if<br/>streaming fails| SEC

    style STREAM fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style S3 fill:#f39c12,stroke:#d68910,stroke-width:2px
```

## Disaster Recovery - Region Failover

### Scenario: Primary Region Failure

```mermaid
sequenceDiagram
    participant ADMIN as Administrator
    participant SEC_ETCD as Secondary etcd
    participant SEC_1 as Standby Leader<br/>(us-west-2)
    participant SEC_2 as Standby Replica 2
    participant SEC_3 as Standby Replica 3
    participant S3 as S3 Storage
    participant DNS as Global DNS

    Note over ADMIN: Primary region us-east-1<br/>completely unavailable

    ADMIN->>ADMIN: Assess disaster scope<br/>Primary region down

    ADMIN->>SEC_1: Connect to standby leader
    SEC_1-->>ADMIN: Connected, in recovery mode

    ADMIN->>SEC_1: Check replication lag
    SEC_1-->>ADMIN: Last WAL received 30s ago

    ADMIN->>S3: Check for any new WAL<br/>from primary
    S3-->>ADMIN: No new WAL (primary offline)

    Note over ADMIN: Decision: Promote<br/>secondary to primary

    ADMIN->>SEC_ETCD: Update Patroni config<br/>Remove standby_cluster

    ADMIN->>SEC_1: patronictl edit-config<br/>Remove standby_cluster section

    SEC_ETCD->>SEC_1: Config updated
    SEC_ETCD->>SEC_2: Config updated
    SEC_ETCD->>SEC_3: Config updated

    ADMIN->>SEC_1: pg_ctl promote<br/>OR patronictl restart

    SEC_1->>SEC_1: Exit recovery mode
    SEC_1->>SEC_1: Promote to primary
    SEC_1-->>ADMIN: Promotion complete

    Note over SEC_1: Now accepting<br/>WRITE traffic

    SEC_1->>SEC_ETCD: Register as primary
    SEC_2->>SEC_1: Connect for replication
    SEC_3->>SEC_1: Connect for replication

    SEC_1-.->SEC_2: Stream replication
    SEC_1-.->SEC_3: Stream replication

    ADMIN->>DNS: Update DNS records<br/>db-primary.example.com<br/>→ us-west-2

    DNS-->>ADMIN: DNS updated (TTL: 60s)

    ADMIN->>S3: Configure WAL archiving<br/>from new primary

    SEC_1->>S3: Start archiving WAL

    Note over SEC_1: us-west-2 now<br/>PRIMARY REGION
```

### Scenario: Planned Switchover

```mermaid
sequenceDiagram
    participant ADMIN as Administrator
    participant PRI as Primary Region<br/>Leader
    participant SEC as Secondary Region<br/>Standby Leader
    participant APP as Applications
    participant DNS as Global DNS

    Note over ADMIN: Planned maintenance<br/>on primary region

    ADMIN->>APP: Notify planned switchover<br/>Enable read-only mode

    APP->>PRI: Stop write traffic
    APP->>SEC: Continue read traffic

    ADMIN->>PRI: Wait for replication<br/>to fully sync

    loop Monitor lag
        ADMIN->>SEC: Check replication lag
        SEC-->>ADMIN: Lag status
    end

    Note over SEC: Lag = 0 bytes

    ADMIN->>PRI: Controlled shutdown<br/>patronictl pause --wait

    PRI->>PRI: Stop accepting connections
    PRI->>PRI: Checkpoint and shutdown

    ADMIN->>SEC: Remove standby config<br/>patronictl edit-config

    ADMIN->>SEC: Promote to primary<br/>patronictl restart

    SEC->>SEC: Exit recovery mode
    SEC->>SEC: Become primary

    Note over SEC: Now PRIMARY region

    ADMIN->>DNS: Update DNS to us-west-2

    ADMIN->>APP: Enable write mode<br/>Point to new primary

    APP->>SEC: Resume write traffic

    Note over PRI: Can be rebuilt as<br/>standby cluster later
```

## Monitoring Multi-Region Setup

```mermaid
graph TB
    subgraph "Primary Region Monitoring"
        PRI_PROM[Prometheus<br/>us-east-1]
        PRI_METRICS["Metrics:<br/>├─ WAL generation rate<br/>├─ Replication slot lag<br/>├─ Network throughput<br/>└─ Transaction rate"]
    end

    subgraph "Secondary Region Monitoring"
        SEC_PROM[Prometheus<br/>us-west-2]
        SEC_METRICS["Metrics:<br/>├─ WAL receive lag<br/>├─ WAL apply lag<br/>├─ Recovery delay<br/>└─ Last WAL received time"]
    end

    subgraph "Global Monitoring"
        THANOS[Thanos/Cortex<br/>Global View]
        GRAF[Grafana<br/>Multi-Region Dashboard]

        ALERTS["Critical Alerts:<br/>├─ Cross-region lag > 10s<br/>├─ Replication broken<br/>├─ Primary region down<br/>├─ Secondary region down<br/>└─ Network partition"]
    end

    subgraph "Cross-Region Metrics"
        CROSS["Cross-Region Health:<br/>├─ Network latency<br/>├─ Bandwidth utilization<br/>├─ WAL shipping delay<br/>├─ Replication slot size<br/>└─ Data lag (bytes/time)"]
    end

    subgraph "Alert Destinations"
        PAGE[PagerDuty<br/>Critical Issues]
        SLACK[Slack<br/>Team Notifications]
        EMAIL[Email<br/>Daily Reports]
    end

    PRI_PROM --> PRI_METRICS
    SEC_PROM --> SEC_METRICS

    PRI_METRICS --> THANOS
    SEC_METRICS --> THANOS

    THANOS --> GRAF
    THANOS --> CROSS
    CROSS --> ALERTS

    ALERTS -->|P0/P1| PAGE
    ALERTS -->|P2/P3| SLACK
    ALERTS -->|Summary| EMAIL

    style PRI_PROM fill:#2ecc71,stroke:#27ae60,stroke-width:2px
    style SEC_PROM fill:#9b59b6,stroke:#8e44ad,stroke-width:2px
    style THANOS fill:#e67e22,stroke:#ca6f1e,stroke-width:3px
    style ALERTS fill:#e74c3c,stroke:#c0392b,stroke-width:2px
```

## Network Architecture

```mermaid
graph TB
    subgraph "AWS us-east-1 (Primary)"
        subgraph "VPC 10.0.0.0/16"
            subgraph "Public Subnets"
                NAT1[NAT Gateway<br/>AZ-1a]
                NAT2[NAT Gateway<br/>AZ-1b]
            end

            subgraph "Private Subnets - Database"
                DB1[PostgreSQL Node 1<br/>10.0.1.10<br/>AZ-1a]
                DB2[PostgreSQL Node 2<br/>10.0.1.20<br/>AZ-1b]
                DB3[PostgreSQL Node 3<br/>10.0.1.30<br/>AZ-1c]
            end

            subgraph "Private Subnets - etcd"
                ETCD1[etcd Node 1<br/>10.0.2.10]
                ETCD2[etcd Node 2<br/>10.0.2.20]
                ETCD3[etcd Node 3<br/>10.0.2.30]
            end
        end
    end

    subgraph "AWS us-west-2 (Secondary)"
        subgraph "VPC 10.1.0.0/16"
            subgraph "Public Subnets"
                NAT3[NAT Gateway<br/>AZ-2a]
                NAT4[NAT Gateway<br/>AZ-2b]
            end

            subgraph "Private Subnets - Database"
                DB4[PostgreSQL Node 1<br/>10.1.1.10<br/>AZ-2a]
                DB5[PostgreSQL Node 2<br/>10.1.1.20<br/>AZ-2b]
                DB6[PostgreSQL Node 3<br/>10.1.1.30<br/>AZ-2c]
            end

            subgraph "Private Subnets - etcd"
                ETCD4[etcd Node 1<br/>10.1.2.10]
                ETCD5[etcd Node 2<br/>10.1.2.20]
                ETCD6[etcd Node 3<br/>10.1.2.30]
            end
        end
    end

    subgraph "Cross-Region Connectivity"
        VPC_PEER[VPC Peering<br/>OR<br/>Transit Gateway<br/>OR<br/>Direct Connect]

        PG_PORT["PostgreSQL Replication<br/>Port 5432<br/>Encrypted with SSL"]
    end

    subgraph "Shared Services"
        S3_MULTI[S3 Multi-Region<br/>Cross-Region Replication<br/>WAL + Backups]
        ROUTE53[Route53<br/>Health Checks<br/>Failover Routing]
    end

    DB1 --> NAT1
    DB2 --> NAT2
    DB3 --> NAT2

    DB4 --> NAT3
    DB5 --> NAT4
    DB6 --> NAT4

    DB1 <-.->|Replication<br/>via VPC Peer| VPC_PEER
    VPC_PEER <-.-> DB4

    DB1 --> S3_MULTI
    DB4 --> S3_MULTI

    ROUTE53 --> DB1
    ROUTE53 --> DB4

    style DB1 fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style DB4 fill:#9b59b6,stroke:#8e44ad,stroke-width:3px
    style VPC_PEER fill:#3498db,stroke:#2980b9,stroke-width:3px
    style S3_MULTI fill:#f39c12,stroke:#d68910,stroke-width:2px
```

## Application Routing Patterns

```mermaid
graph TB
    subgraph "Application Layer"
        APP[Application Servers]

        subgraph "Connection Routing Logic"
            WRITE_CONN[Write Connections<br/>db-primary.example.com]
            READ_CONN[Read Connections<br/>db-read.example.com]
            LOCAL_READ[Local Region Reads<br/>db-read.us-west-2.example.com]
        end
    end

    subgraph "DNS Resolution"
        ROUTE53[Route53 Weighted Routing]

        DNS_PRI["Primary Write Endpoint<br/>db-primary.example.com<br/>→ us-east-1 (Primary)"]

        DNS_READ["Global Read Endpoint<br/>db-read.example.com<br/>→ 70% us-east-1<br/>→ 30% us-west-2"]

        DNS_LOCAL["Regional Read Endpoint<br/>db-read.us-west-2.example.com<br/>→ 100% us-west-2"]
    end

    subgraph "Primary Region - us-east-1"
        LB_PRI[Load Balancer<br/>Primary]
        PRI_WRITE[Primary Node<br/>Read/Write]
        PRI_READ[Replica Nodes<br/>Read Only]
    end

    subgraph "Secondary Region - us-west-2"
        LB_SEC[Load Balancer<br/>Secondary]
        SEC_READ[Standby Nodes<br/>Read Only]
    end

    APP --> WRITE_CONN
    APP --> READ_CONN
    APP --> LOCAL_READ

    WRITE_CONN --> ROUTE53
    READ_CONN --> ROUTE53
    LOCAL_READ --> ROUTE53

    ROUTE53 --> DNS_PRI
    ROUTE53 --> DNS_READ
    ROUTE53 --> DNS_LOCAL

    DNS_PRI --> LB_PRI
    DNS_READ --> LB_PRI
    DNS_READ --> LB_SEC
    DNS_LOCAL --> LB_SEC

    LB_PRI --> PRI_WRITE
    LB_PRI --> PRI_READ
    LB_SEC --> SEC_READ

    style APP fill:#3498db,stroke:#2980b9,stroke-width:2px
    style WRITE_CONN fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style READ_CONN fill:#2ecc71,stroke:#27ae60,stroke-width:2px
    style PRI_WRITE fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style SEC_READ fill:#9b59b6,stroke:#8e44ad,stroke-width:2px
```

## Key Features

### Primary Region
- **Full Patroni Cluster**: Normal operational mode with automatic failover
- **Read-Write Access**: Handles all write operations
- **Local Replication**: Streaming replication between local nodes
- **WAL Archiving**: Continuous archiving to S3
- **WAL Streaming**: Real-time streaming to secondary region

### Secondary Region
- **Standby Cluster Mode**: Entire cluster in recovery/read-only mode
- **Cascading Replication**: Standby leader replicates to local standbys
- **Read-Only Access**: Can serve read queries with some lag
- **Independent DCS**: Separate etcd cluster for local management
- **Disaster Recovery**: Can be promoted to primary during disaster

### Benefits
1. **Geographic Redundancy**: Complete region-level disaster recovery
2. **Low RTO**: Secondary region can be promoted in minutes
3. **Read Scaling**: Distribute read load across multiple regions
4. **Independent Operations**: Secondary cluster manages local replicas independently
5. **Flexible Failover**: Can promote secondary to primary when needed
6. **Data Protection**: Multiple copies across regions with continuous backups

### Important Considerations
1. **Replication Lag**: Cross-region lag typically 100ms-10s depending on method
2. **Network Costs**: Cross-region data transfer has associated costs
3. **Consistency**: Secondary region reads may be slightly behind primary
4. **Failover Impact**: Promotion requires configuration changes and brief downtime
5. **Slot Management**: Replication slots prevent WAL removal until consumed
6. **Monitoring**: Critical to monitor cross-region replication health
