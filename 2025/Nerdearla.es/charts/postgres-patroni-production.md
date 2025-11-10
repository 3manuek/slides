# PostgreSQL Production Architecture

Comprehensive production setup with Patroni, load balancing, connection pooling, monitoring, and backups.

```mermaid
graph TB
    subgraph "Client Layer"
        WC[Write Clients]
        RC[Read Clients]
    end

    subgraph "Load Balancer Options"
        Envoy[Envoy Proxy<br/>Write: :5432<br/>Read: :5433]
        HAProxy[HAProxy Alternative<br/>Write: :5432<br/>Read: :5433]
    end

    subgraph "Connection Pooling Layer"
        subgraph "Write Pool"
            PGBW1[PgBouncer Write 1<br/>:6432]
            PGBW2[PgBouncer Write 2<br/>:6432]
            PGBW3[PgBouncer Write N<br/>:6432]
        end
        subgraph "Read Pool"
            PGBR1[PgBouncer Read 1<br/>:6433]
            PGBR2[PgBouncer Read 2<br/>:6433]
            PGBR3[PgBouncer Read N<br/>:6433]
        end
    end

    subgraph "Database Cluster"
        subgraph "Patroni Cluster"
            PAT1["Patroni Primary<br/>PostgreSQL Master<br/>:5432<br/>Writes + Reads"]
            PAT2["Patroni Replica 1<br/>PostgreSQL Standby<br/>:5432<br/>Reads Only"]
            PAT3["Patroni Replica 2<br/>PostgreSQL Standby<br/>:5432<br/>Reads Only"]
        end
    end

    subgraph "High Availability & Config"
        DCS[(etcd/Consul/Zookeeper<br/>Leader Election<br/>Cluster State)]
    end

    subgraph "Backup & Recovery"
        BACKUP[pgBackRest/WAL-G<br/>Backup Server]
        S3[(S3/Object Storage<br/>WAL Archives<br/>Base Backups)]
    end

    subgraph "Monitoring Stack"
        PROM[Prometheus<br/>Metrics Collection]
        GRAF[Grafana<br/>Visualization]
        EXPORTER1[postgres_exporter<br/>on Primary]
        EXPORTER2[postgres_exporter<br/>on Replica 1]
        EXPORTER3[postgres_exporter<br/>on Replica 2]
        PGBEXPORTER[pgbouncer_exporter]
        PATRONIEXPORTER[patroni endpoints]
    end

    %% Client to LB
    WC -->|Write Traffic| Envoy
    WC -.->|Alternative| HAProxy
    RC -->|Read Traffic| Envoy
    RC -.->|Alternative| HAProxy

    %% LB to PgBouncer
    Envoy -->|Write Port| PGBW1
    Envoy -->|Write Port| PGBW2
    Envoy -->|Write Port| PGBW3
    Envoy -->|Read Port| PGBR1
    Envoy -->|Read Port| PGBR2
    Envoy -->|Read Port| PGBR3

    HAProxy -.->|Write Port| PGBW1
    HAProxy -.->|Write Port| PGBW2
    HAProxy -.->|Read Port| PGBR1
    HAProxy -.->|Read Port| PGBR2

    %% Write PgBouncers to Primary
    PGBW1 --> PAT1
    PGBW2 --> PAT1
    PGBW3 --> PAT1

    %% Read PgBouncers to Replicas
    PGBR1 --> PAT2
    PGBR1 --> PAT3
    PGBR2 --> PAT2
    PGBR2 --> PAT3
    PGBR3 --> PAT2
    PGBR3 --> PAT3

    %% Replication
    PAT1 -.->|Streaming<br/>Replication| PAT2
    PAT1 -.->|Streaming<br/>Replication| PAT3

    %% DCS Communication
    PAT1 <-->|Leader Election<br/>Health Checks| DCS
    PAT2 <-->|Monitor Leader<br/>Health Checks| DCS
    PAT3 <-->|Monitor Leader<br/>Health Checks| DCS

    %% Backup
    PAT1 -->|WAL Shipping| BACKUP
    PAT2 -.->|Optional<br/>Backup Source| BACKUP
    BACKUP --> S3
    BACKUP -.->|PITR Restore| PAT1

    %% Monitoring
    PAT1 --> EXPORTER1
    PAT2 --> EXPORTER2
    PAT3 --> EXPORTER3
    PGBW1 --> PGBEXPORTER
    PGBR1 --> PGBEXPORTER
    PAT1 -->|/metrics| PATRONIEXPORTER
    PAT2 -->|/metrics| PATRONIEXPORTER
    PAT3 -->|/metrics| PATRONIEXPORTER

    EXPORTER1 --> PROM
    EXPORTER2 --> PROM
    EXPORTER3 --> PROM
    PGBEXPORTER --> PROM
    PATRONIEXPORTER --> PROM
    DCS -->|etcd metrics| PROM

    PROM --> GRAF

    style PAT1 fill:#2ecc71,stroke:#27ae60,stroke-width:3px
    style PAT2 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style PAT3 fill:#3498db,stroke:#2980b9,stroke-width:2px
    style Envoy fill:#9b59b6,stroke:#8e44ad,stroke-width:3px
    style HAProxy fill:#9b59b6,stroke:#8e44ad,stroke-width:2px,stroke-dasharray: 5 5
    style DCS fill:#e74c3c,stroke:#c0392b,stroke-width:2px
    style S3 fill:#f39c12,stroke:#d68910,stroke-width:2px
    style BACKUP fill:#f39c12,stroke:#d68910,stroke-width:2px
    style PROM fill:#e67e22,stroke:#ca6f1e,stroke-width:2px
    style GRAF fill:#e67e22,stroke:#ca6f1e,stroke-width:2px
```

## Architecture Components

### Load Balancing
- **Envoy Proxy** (primary): Modern cloud-native proxy with advanced routing
- **HAProxy** (alternative): Proven high-performance TCP/HTTP load balancer
- Separate ports for write (5432) and read (5433) traffic

### Connection Pooling
- **Write Pool**: Dedicated PgBouncer instances routing to primary
- **Read Pool**: Dedicated PgBouncer instances routing to replicas
- Reduces connection overhead and improves database performance

### Database Cluster
- **Patroni Primary**: Handles all writes and can serve reads
- **Patroni Replicas**: Handle read-only queries for horizontal scaling
- **Streaming Replication**: Near real-time data synchronization
- **Automatic Failover**: Patroni promotes replica to primary on failure

### High Availability
- **DCS (etcd/Consul/Zookeeper)**: Distributed consensus for leader election
- Automatic failover with minimal downtime
- Health checks and cluster state management

### Backup & Recovery
- **pgBackRest/WAL-G**: Enterprise backup solutions
- **S3/Object Storage**: Durable, scalable backup storage
- **WAL Archiving**: Continuous backup of transaction logs
- **Point-in-Time Recovery (PITR)**: Restore to any point in time

### Monitoring Stack
- **Prometheus**: Time-series metrics collection
- **Grafana**: Visualization and alerting dashboards
- **postgres_exporter**: PostgreSQL metrics (connections, queries, locks, etc.)
- **pgbouncer_exporter**: Connection pool metrics
- **Patroni metrics**: Cluster health and replication lag

## Features

- **High Availability**: Automatic failover with Patroni and DCS
- **Read Scaling**: Load distribution across replicas
- **Connection Efficiency**: PgBouncer fleet reduces database connection overhead
- **Disaster Recovery**: Continuous backups with PITR capability
- **Full Observability**: Comprehensive metrics and dashboards
- **Flexible Load Balancing**: Choice of Envoy or HAProxy
- **Traffic Segregation**: Separate read/write routing paths
