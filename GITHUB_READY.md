# GitHub Ready Checklist

This repository is aligned to the current minimal implementation.

## Included Runtime Objects

- `src/zcl_cds_migrator.clas.abap`
- `src/zcl_cds_migrator.clas.xml`
- `src/zcl_cds_migrator.clas.testclasses.abap`
- `src/zcl_cds_migrator.clas.testclasses.xml` (if present in your export)
- `src/zcds_migration.prog.abap`
- `src/zcds_migration.prog.xml`
- `src/package.devc.xml`

## Included Documentation

- `README.md`
- `ARCHITECTURE.md`
- `DEPLOYMENT.md`
- `METHOD_DOCUMENTATION.md`
- `TRANSFORMATION_GUIDE.md`
- `PROJECT_SUMMARY.md`
- `QUICKREF.md`

## Pre-Push Validation

1. Run ABAP Unit for `ZCL_CDS_MIGRATOR`.
2. Run `ZCDS_MIGRATION` in display mode and verify output.
3. Ensure changed files are intentional.
4. Ensure `CLAUDE.md` is not staged.

## Git Check

```
git status
git add src README.md ARCHITECTURE.md DEPLOYMENT.md METHOD_DOCUMENTATION.md TRANSFORMATION_GUIDE.md PROJECT_SUMMARY.md QUICKREF.md
git commit -m "docs: align repository docs with current source"
```

## Important Notes

- Current `create_entity` is a placeholder and returns `abap_false`.
- The production-safe path is display mode + manual controlled activation.

---

Last Updated: 2026-05-30
