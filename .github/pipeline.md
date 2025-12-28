
## Pipeline Overview

### Triggers
- **Push to `main`**: Deploys to mainnet environment
- **Push to `stage`**: Deploys to stokenet environment
- **Manual dispatch**: Choose environment

### Key Features

#### Concurrency Controls
- Top-level: `deploy-${{ github.ref }}` - Queues deployments from same branch
- Per-environment: `mainnet-deployment`, `stokenet-deployment`, `shared-deployment`
- Prevents Terraform state conflicts

#### Path Filters
Resources only deploy when their configuration changes:
- `resources/shared/**`
- `resources/mainnet/**`
- `resources/stokenet/**`

### Deployment Sequence

1. **Validation** (on PR): Terraform fmt + validate
2. **Environment Selection**: Determine mainnet or stokenet
3. **Infrastructure**:
   - Deploy shared (always)
   - Deploy mainnet (if main branch)
   - Deploy stokenet (if stage branch)


```mermaid
---
config:
  layout: elk
---
flowchart TB
    Start([Workflow Trigger<br/>main or stage branch]) --> PreCheck{Precheck<br/>Validation}
    PreCheck -- Pass --> SetEnv[Set Environment<br/>main → mainnet<br/>stage → stokenet]
    PreCheck -- Pass --> Filter[Filter Changed Files<br/>- resources/*]
    PreCheck -- Fail --> End([End])
    
    SetEnv --> EnvReady[Environment Determined]
    
    subgraph Infrastructure[Infrastructure Deployment]
        EnvReady --> DeployShared[Deploy Shared<br/>Admin Resources<br/>Budget Alerts]
        EnvReady --> DeployMainnet{Deploy Mainnet?}
        EnvReady --> DeployStokenet{Deploy Stokenet?}
        
        DeployMainnet -- if mainnet --> MainnetDeploy[Deploy Mainnet<br/>Backend + Observability]
        DeployStokenet -- if stokenet --> StokenetDeploy[Deploy Stokenet<br/>Backend + Observability]
        
        DeployShared --> InfraReady([Infrastructure Ready])
        MainnetDeploy --> InfraReady
        StokenetDeploy --> InfraReady
    end
    
    style Start fill:#e1f5ff
    style PreCheck fill:#fff4e1
    style SetEnv fill:#e8f5e9
    style Filter fill:#f3e5f5
    style End fill:#ffe1e1
    style DeployShared fill:#bbdefb
    style MainnetDeploy fill:#bbdefb
    style StokenetDeploy fill:#bbdefb
    style InfraReady fill:#fff9c4
```
