# Install via abapGit

## Repository

- URL: https://github.com/jeremyyma/CDS2Entity.git
- Main package content: one class + one report + test include

## Steps

1. Open transaction `ZABAPGIT`.
2. Choose New Online.
3. Enter repository URL.
4. Select target package (for trial use `$TMP`).
5. Pull and activate all objects.

## Expected Objects After Import

- Class `ZCL_CDS_MIGRATOR`
- Report `ZCDS_MIGRATION`
- ABAP Unit test include for class

## First Run

```
SE38 -> ZCDS_MIGRATION
P_PACK = <your package>
P_DISP = X
F8
```

## Verification

- ALV shows classic CDS records when found.
- `new_name` and `new_source` are filled after transform.

## Unit Test

```
SE24 -> ZCL_CDS_MIGRATOR -> Test -> Execute
```

## Current Functional Limitation

- Commit mode currently calls placeholder `create_entity`.
- New DDLS objects are not automatically persisted yet.

---

Last Updated: 2026-05-30
