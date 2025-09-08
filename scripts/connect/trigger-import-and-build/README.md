# 🔁 Trigger Data Source Import(s) and System Build Script

This PowerShell script automates the process of:

1. Authenticating against a system.
2. Importing data from one or more data sources.
3. Triggering a system build and deployment.

It provides detailed status updates throughout each step, ensuring transparency during execution.

---

## 🚀 Usage

```powershell
.\trigger-import-and-build.ps1 \
  -UserLogin "admin" \
  -Password "password" \
  -DataSourceIds @(1,2,3) \
  -CDPTableMappingIds @(1,2)
  -SystemDefinitionId 1 \
  -LoginBaseUrl "http://localhost:60080" \
  -ApiBaseUrl "https://localhost:7236" \
  -DataViewName "holidays"
  -WaitForOrbit $false
```

---

## 🧾 Parameters

| Name                 | Type     | Required | Description                                                               |
| -------------------- | -------- | -------- | ------------------------------------------------------------------------- |
| `UserLogin`          | `string` | ✅       | Username for authentication.                                              |
| `Password`           | `string` | ✅       | Password for authentication.                                              |
| `DataSourceIds`      | `int[]`  | ✅       | Array of data source IDs to import.                                       |
| `CDPTableMappingIds` | `int[]`  | ✅       | Array of CDP table mappings to import.                                    |
| `SystemDefinitionId` | `int`    | ✅       | ID of the system definition to build.                                     |
| `LoginBaseUrl`       | `string` | ❌       | Base URL for login API (default: `http://localhost:60080`).               |
| `ApiBaseUrl`         | `string` | ❌       | Base URL for data and build APIs (default: `https://localhost:7236`).     |
| `DataViewName`       | `string` | ❌       | Name of the data view context (default: `"holidays"`).                    |
| `WaitForOrbit`       | `bool`   | ❌       | Should the script keep polling until Orbit has updated (default: `false`) |

---

## 🔧 Workflow

1. **Authentication**  
   Logs in using the provided credentials and retrieves an access token.

2. **Data Import**  
   Iterates over each `DataSourceId` and performs a `Replace` import. Waits for each import to complete before moving on.

3. **CDP Table Mapping Import**
   Iterates over each `CDPTableMappingId` and performs an import from the associated data source. Waits for each import to complete to the CDP (inc ID resolution etc) before moving on.

4. **System Build & Deployment**  
   Initiates a system build using the specified `SystemDefinitionId`, waits for completion, retrieves the deployment ID, and then waits for deployment to finish.

---

## 📦 Output

- Displays the access token (for debugging).
- Logs import status for each data source.
- Logs cdp import status for each CDP table mapping import
- Shows build and deployment status updates.
- Exits with code `0` if successful, `1` on failure.

---

## 📝 Notes

- You can get the Data Source and System Definition IDs from the URL inside Connect, these won't change.
- You can get the table mapping Id from inside the connect app e.g. www.myorbitinstance.com/Connect/data-mappings/customer-data/{id}
- All import and system build operations are performed **sequentially**.
- Errors during import or build do not halt the script, but failures are clearly indicated.
- Ensure that both the login and API base URLs are reachable from your environment.

---
