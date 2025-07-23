# 1PassHound

## Overview

## Components

### Kind Definition

```powershell
$1passDefinition = Get-Content ./kinddefinition.json
BHAPI /custom-nodes POST ($1passdefinition) -expand data
```

### Collector

#### Required Permissions
