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

##### Default Group Permissions

| Permission Name             | Owners | Administrators | Recovery | Provision Managers |
| --------------------------- | ------ | -------------- | -------- | ------------------ |
| ADD_PERSON                  | x      | x              |          |                    |
| CHANGE_PERSON_NAME          | x      | x              |          |                    |
| CHANGE_TEAM_ATTRIBUTES      | x      | x              |          |                    |
| CHANGE_TEAM_DOMAIN          | x      | x              |          |                    |
| CHANGE_TEAM_SETTINGS        | x      | x              |          |                    |
| CREATE_VAULTS               | x      | x              |          |                    |
| DELETE_PERSON               | x      | x              |          |                    |
| DELETE_TEAM                 | x      |                |          |                    |
| MANAGE_BILLING              | x      |                |          |                    |
| MANAGE_GROUPS               | x      | x              |          |                    |
| MANAGE_TEMPLATES            | x      | x              |          |                    |
| MANAGE_VAULTS               | x      |                |          |                    |
| PROVISION_PEOPLE            |        |                |          | x                  |
| SUSPEND_PERSON              | x      | x              |          |                    |
| SUSPEND_TEAM                | x      |                |          |                    |
| RECOVER_ACCOUNTS            | x      | x              | x        |                    |
| VIEW_ACTIVITY_LOGS          | x      | x              |          |                    |
| VIEW_ADMINISTRATIVE_SIDEBAR | x      | x              | x        |                    |
| VIEW_BILLING                | x      |                |          |                    |
| VIEW_PEOPLE                 | x      | x              | x        |                    |
| VIEW_TEAM_SETTINGS          | x      | x              |          |                    |
| VIEW_TEMPLATES              | x      | x              |          |                    |
| VIEW_VAULTS                 | x      | x              |          |                    |

##### Group Permission Categories

| Permission Name             | View Administrative Sidebar | Manage Settings | Manage Billings | Delete Account | Suspend People | Invite & Remove People | Manage People | Create Vaults | Recover Accounts | Manage All Groups |
| --------------------------- | --------------------------- | --------------- | --------------- | -------------- | -------------- | ---------------------- | ------------- | ------------- | ---------------- | ----------------- |
| ADD_PERSON                  |                             |                 |                 |                |                | *6*                    |               |               |                  |                   |
| CHANGE_PERSON_NAME          |                             |                 |                 |                |                |                        | *7*           |               |                  |                   |
| CHANGE_TEAM_ATTRIBUTES      |                             | *2*             |                 | 2              |                |                        |               |               |                  |                   |
| CHANGE_TEAM_DOMAIN          |                             | *2*             |                 | 2              |                |                        |               |               |                  |                   |
| CHANGE_TEAM_SETTINGS        |                             | *2*             |                 | 2              |                |                        |               |               |                  |                   |
| CREATE_VAULTS               |                             |                 |                 |                |                |                        |               | *8*           |                  |                   |
| DELETE_PERSON               |                             |                 |                 |                |                | *6*                    |               |               |                  |                   |
| DELETE_TEAM                 |                             |                 |                 | *4*            |                |                        |               |               |                  |                   |
| MANAGE_BILLING              |                             |                 | *3*             | 3              |                |                        |               |               |                  |                   |
| MANAGE_GROUPS               |                             |                 |                 |                |                |                        |               |               |                  | *10*              |
| MANAGE_TEMPLATES            |                             | *2*             |                 | 2              |                |                        |               |               |                  |                   |
| MANAGE_VAULTS               |                             |                 |                 |                |                |                        |               |               |                  |                   |
| PROVISION_PEOPLE            |                             |                 |                 |                |                |                        |               |               |                  |                   |
| SUSPEND_PERSON              |                             |                 |                 |                | *5*            | 5                      |               |               |                  |                   |
| SUSPEND_TEAM                |                             |                 |                 | *4*            |                |                        |               |               |                  |                   |
| RECOVER_ACCOUNTS            |                             |                 |                 |                |                |                        |               |               |                  |                   |
| VIEW_ACTIVITY_LOGS          | *1*                         | 1               |                 |                |                |                        |               |               | *9*              |                   |
| VIEW_ADMINISTRATIVE_SIDEBAR | *1*                         | 1               |                 | 1              | 1              | 1                      | 1             |               | 1                | 1                 |
| VIEW_BILLING                |                             |                 | *3*             | 3              |                |                        |               |               |                  |                   |
| VIEW_PEOPLE                 | *1*                         | 1               |                 | 1              | 1              | 1                      | 1             |               | 1                | 1                 |
| VIEW_TEAM_SETTINGS          | *1*                         | 1               |                 | 1              | 1              | 1                      | 1             |               | 1                | 1                 |
| VIEW_TEMPLATES              | *1*                         | 1               |                 | 1              | 1              | 1                      | 1             |               | 1                | 1                 |
| VIEW_VAULTS                 | *1*                         | 1               |                 | 1              | 1              | 1                      | 1             |               | 1                | 1                 |
