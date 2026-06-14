# Custom History Component - Apex Cursor Enhancement

## Overview
This document outlines the enhancements made to the Custom History component to use Apex Cursors for efficient pagination and data transfer following Salesforce best practices.

## Key Improvements

### 1. Apex Cursor Implementation
**File:** `SobjectFieldHistoryController.cls`

#### Problem with Previous Approach
- Used SOQL with `OFFSET` and `LIMIT`, which loads all records up to the offset position into memory
- Inefficient for large datasets as memory consumption increases with pagination depth
- Poor performance when navigating to later pages

#### Solution: Apex Cursor
```apex
Database.Cursor cursor = Database.getCursor(query);
if (offsetSize > 0) {
    cursor.moveTo(offsetSize);
}
result = cursor.fetch(limitSize);
```

**Benefits:**
- ✅ Lazy loading: Records are loaded only when needed
- ✅ Memory efficient: Constant memory usage regardless of offset position
- ✅ Better performance for large datasets
- ✅ Follows Salesforce recommended patterns for pagination

### 2. Enhanced Method: `sendHistoryFieldMappingToUI()`

**Enhancements:**
- Uses `Database.getCursor()` with dynamic SOQL query
- Implements `cursor.moveTo(offsetSize)` for efficient position navigation
- Uses `cursor.fetch(limitSize)` to retrieve only required records
- Added input validation with `IllegalArgumentException`
- Enhanced debugging with detailed logging
- Comprehensive JSDoc comments

**Method Signature:**
```apex
@AuraEnabled(cacheable=true)
public static List<History_Object__c> sendHistoryFieldMappingToUI(
    Id recId, 
    Integer limitSize, 
    Integer offsetSize
)
```

### 3. New Method: `getHistoryRecordCount()`

**Purpose:** Retrieve the total number of history records for accurate pagination UI

**Enhancements:**
- Uses aggregate `COUNT()` query for performance
- Enables proper "Next" button disabling logic
- Provides accurate pagination information to LWC
- Cached with `@AuraEnabled(cacheable=true)` to reduce network calls

```apex
@AuraEnabled(cacheable=true)
public static Integer getHistoryRecordCount(Id recId)
```

### 4. LWC Improvements

**File:** `customHistory.js`

#### New Tracked Properties
```javascript
@track objectdata = [];
@track totalRecordCount = 0;  // NEW
wiredCountResult;              // NEW
currentPage = 1;               // NEW
```

#### Enhanced Getters

**`isNextDisabled`** - Now based on actual record count
```javascript
get isNextDisabled() {
    return (this.rowOffset + this.rowLimit) >= this.totalRecordCount;
}
```

**`paginationInfo`** - Shows "X - Y of Z" format
```javascript
get paginationInfo() {
    const startRecord = this.totalRecordCount === 0 ? 0 : this.rowOffset + 1;
    const endRecord = Math.min(this.rowOffset + this.rowLimit, this.totalRecordCount);
    return `${startRecord} - ${endRecord} of ${this.totalRecordCount}`;
}
```

#### Wire Methods

**`wiredContacts()`** - Fetches paginated history data
```javascript
@wire(getFieldsData, { 
    recId: '$recordId', 
    limitSize: '$rowLimit', 
    offsetSize: '$rowOffset' 
})
```

**`wiredRecordCount()`** - NEW - Fetches total record count
```javascript
@wire(getHistoryRecordCount, { recId: '$recordId' })
```

#### Updated Handlers

**`handleRefresh()`** - Now refreshes both data and count
```javascript
async handleRefresh() {
    await refreshApex(this.wiredHistoryResult);
    await refreshApex(this.wiredCountResult);  // NEW
}
```

**`handleNext()` & `handlePrevious()`** - Enhanced with boundary checks
- Validates offset against total record count
- Prevents invalid pagination states
- Tracks current page number

### 5. HTML Template Updates

**Enhanced Pagination Info:**
```html
<p class="slds-text-body_small slds-text-color_weak">
    {paginationInfo} • Sorted by Date • Updated a few seconds ago
</p>
```

**Result:** Shows "1 - 10 of 45" instead of just "10 items"

## Performance Comparison

| Aspect | OFFSET/LIMIT | Apex Cursor |
|--------|-------------|------------|
| Memory Usage (Page 50) | High | Constant |
| Query Performance | Degrades | Consistent |
| Large Datasets (10K+) | Slow | Fast |
| Best Practice | ❌ Not recommended | ✅ Recommended |

## Salesforce Best Practices Followed

1. **Apex Cursor Usage** - Preferred for large dataset pagination
2. **Input Validation** - Null checks and type safety
3. **Error Handling** - Try-catch blocks with logging and exception tracking
4. **Caching** - `@AuraEnabled(cacheable=true)` for performance
5. **Null Safety** - Defensive null checks throughout
6. **Code Comments** - JSDoc-style documentation
7. **Wire Services** - Proper reactive data binding in LWC
8. **Aggregate Queries** - Using `COUNT()` instead of loading all records

## Testing Recommendations

### Apex Tests
```apex
// Test cursor pagination
List<History_Object__c> page1 = SobjectFieldHistoryController.sendHistoryFieldMappingToUI(recId, 10, 0);
List<History_Object__c> page2 = SobjectFieldHistoryController.sendHistoryFieldMappingToUI(recId, 10, 10);

// Verify count
Integer totalCount = SobjectFieldHistoryController.getHistoryRecordCount(recId);
Assert.areEqual(expectedCount, totalCount);
```

### LWC Tests
- Verify cursor data loads on component initialization
- Test next/previous button state based on record count
- Verify pagination info displays correctly
- Test refresh functionality updates both data and count

## Migration Notes

- Backward compatible - no breaking changes to existing components
- Requires API version 55.0 or higher for `Database.Cursor` support
- No schema changes required
- Cache clearing may be needed after deployment

## Future Enhancements

1. **Batch Size Optimization** - Allow configurable page sizes
2. **Sorting** - Implement column-based sorting
3. **Filtering** - Add field-value filters
4. **Export Functionality** - Export paginated results
5. **Infinite Scroll** - Replace pagination with lazy loading
