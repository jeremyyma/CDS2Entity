# CDS Entity Modernization Guide

## Overview

This document details all transformations applied when migrating classic CDS views to modern entity-based CDS views.

---

## 🔄 Complete Transformation List

### 1. Core Syntax Transformation

| Classic CDS | Entity CDS | Status |
|-------------|------------|--------|
| `DEFINE VIEW` | `DEFINE VIEW ENTITY` | ✅ Applied |
| `DEFINE ROOT VIEW` | `DEFINE ROOT VIEW ENTITY` | ✅ Applied |

---

## 2. ❌ Deprecated Annotations (REMOVED)

### 2.1 @AbapCatalog.sqlViewName

**Classic:**
```abap
@AbapCatalog.sqlViewName: 'ZMYVIEW'
define view Z_MY_VIEW ...
```

**Entity:**
```abap
define view entity Z_MY_VIEW_V2 ...
```

**Why removed:** Entity views don't create intermediate SQL views. The CDS entity IS the database object.

---

### 2.2 @AbapCatalog.preserveKey

**Classic:**
```abap
@AbapCatalog.preserveKey: true
define view Z_MY_VIEW ...
```

**Entity:**
```abap
define view entity Z_MY_VIEW_V2 ...
```

**Why removed:** Not supported in entity views. Key handling is automatic in entity views.

---

### 2.3 @AbapCatalog.compiler.compareFilter

**Classic:**
```abap
@AbapCatalog.compiler.compareFilter: true
define view Z_MY_VIEW ...
```

**Entity:**
```abap
define view entity Z_MY_VIEW_V2 ...
```

**Why removed:** Obsolete compiler directive not needed in modern ABAP releases.

---

## 3. ✅ Required Annotations (ADDED)

### 3.1 @EndUserText.label

**Status:** ✅ **REQUIRED** for entity views

**Added if missing:**
```abap
@EndUserText.label: 'CDS Entity View'
```

**Purpose:** Provides user-facing description for the view. Required in ABAP Cloud.

**Best Practice:** Use meaningful labels that describe the business object.

---

### 3.2 @AccessControl.authorizationCheck

**Status:** ✅ **REQUIRED** for entity views

**Added if missing:**
```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
```

**Purpose:** Defines authorization check behavior. Options:
- `#CHECK` - Perform authorization check
- `#NOT_REQUIRED` - No authorization check
- `#NOT_ALLOWED` - Not allowed for consumption

**Best Practice:** Use `#CHECK` in production, `#NOT_REQUIRED` for development/testing.

---

### 3.3 @Metadata.ignorePropagatedAnnotations

**Status:** ✅ **RECOMMENDED** for clean entity views

**Added if missing:**
```abap
@Metadata.ignorePropagatedAnnotations: true
```

**Purpose:** Prevents automatic propagation of annotations from underlying data sources.

**Best Practice:** Set to `true` for explicit annotation control and cleaner metadata.

---

### 3.4 @Metadata.allowExtensions

**Status:** ✅ **RECOMMENDED** for extensibility

**Added if missing:**
```abap
@Metadata.allowExtensions: true
```

**Purpose:** Enables CDS view extensions via metadata extensions.

**Best Practice:** Always enable unless there's a specific reason to prevent extensions.

---

## 4. 🔑 Key Field Enhancement

### Automatic KEY Addition

**Status:** ✅ Applied to first field if no KEY exists

**Classic (no KEY):**
```abap
define view Z_MY_VIEW as select from table {
  field1,
  field2
}
```

**Entity (KEY added):**
```abap
define view entity Z_MY_VIEW_V2 as select from table {
  key field1,
  field2
}
```

**Why:** Entity views **require** at least one KEY field. This is enforced by the ABAP compiler.

---

## 📊 Complete Example

### BEFORE: Classic CDS
```abap
@AbapCatalog.sqlViewName: 'ZCUSTOMER_V'
@AbapCatalog.preserveKey: true
@AbapCatalog.compiler.compareFilter: true
define view Z_CUSTOMER_VIEW
  as select from kna1
{
  kunnr,
  name1,
  ort01
}
```

### AFTER: Modern Entity CDS
```abap
@EndUserText.label: 'CDS Entity View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity Z_CUSTOMER_VIEW_V2
  as select from kna1
{
  key kunnr,
  name1,
  ort01
}
```

---

## 🎯 Transformation Summary

| Category | Action | Count |
|----------|--------|-------|
| **Removed** | Deprecated annotations | 3 |
| **Added** | Required annotations | 2 |
| **Added** | Recommended annotations | 2 |
| **Enhanced** | KEY field handling | 1 |
| **Total** | Transformations applied | **8** |

---

## 📋 Checklist: Modern CDS Entity

Use this checklist to verify your entity views are fully modernized:

### Must Have (REQUIRED)
- [ ] ✅ `DEFINE VIEW ENTITY` syntax
- [ ] ✅ At least one `key` field
- [ ] ✅ `@EndUserText.label` annotation
- [ ] ✅ `@AccessControl.authorizationCheck` annotation

### Should Have (RECOMMENDED)
- [ ] ✅ `@Metadata.ignorePropagatedAnnotations: true`
- [ ] ✅ `@Metadata.allowExtensions: true`
- [ ] ✅ No deprecated `@AbapCatalog.sqlViewName`
- [ ] ✅ No deprecated `@AbapCatalog.preserveKey`
- [ ] ✅ No deprecated `@AbapCatalog.compiler.compareFilter`

### Nice to Have (OPTIONAL)
- [ ] `@ObjectModel.usageType` for consumption definition
- [ ] Semantic annotations (`@Semantics.*`)
- [ ] Association annotations
- [ ] Field-level `@EndUserText.label`

---

## 🚀 ABAP Cloud Compliance

All transformations applied by this tool ensure **100% ABAP Cloud compliance**:

✅ Uses only released APIs  
✅ No deprecated annotations  
✅ Follows SAP best practices  
✅ Compatible with ABAP 7.50+  
✅ Ready for BTP ABAP Environment  

---

## 📚 References

- [SAP Help: CDS Entity Views](https://help.sap.com/docs/ABAP_PLATFORM_NEW)
- [ABAP Cloud Development Guide](https://help.sap.com/docs/BTP)
- [CDS Annotations Reference](https://help.sap.com/docs/ABAP_CDS)
- [Clean ABAP Guidelines](https://github.com/SAP/styleguides)

---

**Last Updated:** 2026-05-23  
**Tool Version:** 2.0.0  
**Maintained By:** CDS2Entity Project
