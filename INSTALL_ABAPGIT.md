# Installation via abapGit

## Prerequisites

- SAP NetWeaver 7.50 or higher
- abapGit installed in your system
  - Get it from: https://abapgit.org
  - Installation guide: https://docs.abapgit.org/guide-install.html

## Installation Steps

### Method 1: Online Repository (Recommended)

1. **Open abapGit**
   - Transaction: `ZABAPGIT` (or your custom transaction)

2. **Clone Repository**
   - Click "New Online"
   - Enter Git Repository URL: `https://github.com/jeremyyma/CDS2Entity.git`
   - Package: Enter your package name (e.g., `ZCDS_MIGRATION` or `$TMP` for testing)
   - Branch: `main` (default)
   - Click "Create Online Repo"

3. **Pull Objects**
   - abapGit will display all objects to be imported
   - Review the list:
     - 4 Classes (ZCL_CDS_*)
     - 1 Test Class (ZCL_CDS_TEST)
     - 2 Reports (ZCDS_MIGRATION_TOOL, ZCDS_MIGRATION_EXAMPLES)
   - Click "Pull"
   - Select a transport request or create a new one

4. **Activate Objects**
   - After pull completes, activate all objects
   - Go to SE80 → Your Package → Right-click → Activate All

5. **Verify Installation**
   - Transaction: SE38
   - Run: `ZCDS_MIGRATION_TOOL`
   - You should see the selection screen

### Method 2: Offline Repository (Air-Gapped Systems)

1. **Download ZIP**
   - Go to: https://github.com/jeremyyma/CDS2Entity
   - Click "Code" → "Download ZIP"
   - Extract to your local machine

2. **Import via abapGit**
   - Open abapGit (`ZABAPGIT`)
   - Click "New Offline"
   - Package: Enter your package name
   - Folder: Browse to extracted folder
   - Click "Create Offline Repo"

3. **Import Objects**
   - Click "Import ZIP"
   - Select the downloaded ZIP file
   - Click "Import"
   - Select transport request

4. **Activate**
   - Activate all imported objects

### Method 3: Manual Installation

If abapGit is not available:

1. **Create Package**
   - SE80 → Create package `ZCDS_MIGRATION`

2. **Create Classes** (SE24)
   - Create each class:
     - `ZCL_CDS_SCANNER`
     - `ZCL_CDS_DEPENDENCY_ANALYZER`
     - `ZCL_CDS_MIGRATOR`
     - `ZCL_CDS_MIGRATION_MANAGER`
     - `ZCL_CDS_TEST`
   - Copy code from `src/*.clas.abap` files

3. **Create Reports** (SE38)
   - Create programs:
     - `ZCDS_MIGRATION_TOOL`
     - `ZCDS_MIGRATION_EXAMPLES`
   - Copy code from `src/*.prog.abap` files

4. **Activate All**
   - SE80 → Package → Activate all objects

## Post-Installation

### 1. Run Tests
```
SE24 → ZCL_CDS_TEST → Execute Unit Tests (Ctrl+Shift+F10)
```

### 2. First Use
```
SE38 → ZCDS_MIGRATION_TOOL
- Enter a test package
- Check "Display Only"
- Press F8
```

### 3. Configuration
- No additional configuration required
- Tool is ready to use

## Troubleshooting

### Issue: "Package does not exist"
**Solution**: Create the package first in SE80

### Issue: "Syntax errors after import"
**Solution**: 
- Check SAP version (7.50+ required)
- Activate all objects
- Check dependencies

### Issue: "abapGit not found"
**Solution**: Install abapGit from https://abapgit.org

### Issue: "Authorization error"
**Solution**: You need S_DEVELOP authorization for:
- ACTVT: 01, 02, 03
- OBJTYPE: CLAS, PROG
- DEVCLASS: Your package

## Updating

### Online Repository
1. Open abapGit
2. Select repository
3. Click "Pull"
4. Activate updated objects

### Offline Repository
1. Download latest ZIP
2. Import via abapGit
3. Overwrite existing objects

## Uninstallation

1. Open abapGit
2. Select repository
3. Click "Uninstall"
4. Or manually delete objects in SE80

## Support

- **Documentation**: See README.md, QUICKREF.md, DEPLOYMENT.md
- **Issues**: https://github.com/jeremyyma/CDS2Entity/issues
- **Examples**: Run ZCDS_MIGRATION_EXAMPLES

## Version Information

- **Current Version**: 1.0.0
- **Minimum SAP Version**: 7.50
- **abapGit Version**: Any recent version
- **Last Updated**: 2026-05-23

## What Gets Installed

```
ZCDS_MIGRATION/
├── Classes (4)
│   ├── ZCL_CDS_SCANNER
│   ├── ZCL_CDS_DEPENDENCY_ANALYZER
│   ├── ZCL_CDS_MIGRATOR
│   └── ZCL_CDS_MIGRATION_MANAGER
├── Test Classes (1)
│   └── ZCL_CDS_TEST
└── Reports (2)
    ├── ZCDS_MIGRATION_TOOL
    └── ZCDS_MIGRATION_EXAMPLES
```

## Next Steps

After installation:
1. Read QUICKREF.md for quick commands
2. Review DEPLOYMENT.md for detailed setup
3. Try examples in ZCDS_MIGRATION_EXAMPLES
4. Run your first migration with ZCDS_MIGRATION_TOOL

---

**Happy Migrating!** 🚀
