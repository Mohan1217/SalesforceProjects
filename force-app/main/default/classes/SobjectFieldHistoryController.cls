/**
 * @description Controller class for managing custom field history tracking
 * Uses Apex Cursor for efficient pagination following Salesforce best practices
 */
public class SobjectFieldHistoryController {
    
    /**
     * @description Tracks field changes by comparing old and new records
     * Creates history records for any field changes detected
     * @param newList List of new/updated sobject records
     * @param oldList Map of old sobject records by Id
     */
    public static void getHistoryFieldMapping(List<SObject> newList, Map<Id, SObject> oldList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        
        try {
            List<History_Object__c> historySObjectList = new List<History_Object__c>();
            Schema.SObjectType objectType = newList[0].getSObjectType();
            String objectName = objectType.getDescribe().getName();
            
            // Fetch metadata configuration for tracked fields
            Sobject_History_Fields_Tracking__mdt sobjectHistoryMetadata = [
                SELECT Field_Set__c, Object_Name__c 
                FROM Sobject_History_Fields_Tracking__mdt 
                WHERE Object_Name__c = :objectName 
                LIMIT 1
            ];
            
            Set<String> fieldSet = new Set<String>();
            
            // Parse comma-separated field names from metadata
            if (String.isNotBlank(sobjectHistoryMetadata.Field_Set__c)) {
                for (String fieldName : sobjectHistoryMetadata.Field_Set__c.split(';')) {
                    fieldSet.add(fieldName.trim());
                }
            }
            
            Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
            
            // Iterate through new records and compare with old records
            for (SObject eachRec : newList) {
                Id recordId = (Id) eachRec.get('Id');
                SObject oldRec = oldList.get(recordId);
                
                if (oldRec == null) {
                    continue;
                }
                
                // Compare each tracked field
                for (String eachField : fieldSet) {
                    Object oldValObj = oldRec.get(eachField);
                    Object newValObj = eachRec.get(eachField);
                    String oldVal = String.valueOf(oldValObj);
                    String newVal = String.valueOf(newValObj);
                    
                    // Create history record if values differ
                    if (oldVal != newVal) {
                        History_Object__c newFieldChange = new History_Object__c();
                        newFieldChange.Name = objectName + ' - ' + String.valueOf(recordId);
                        newFieldChange.Record_Id__c = String.valueOf(recordId);
                        newFieldChange.Old_Value__c = oldVal;
                        newFieldChange.New_Value__c = newVal;
                        newFieldChange.Field_Name__c = fieldMap.get(eachField).getDescribe().getLabel();
                        newFieldChange.Object_Name__c = objectName;
                        newFieldChange.Created_Date__c = String.valueOf(System.now());
                        newFieldChange.Owner__c = UserInfo.getName();
                        historySObjectList.add(newFieldChange);
                    }
                }
            }
            
            // Bulk insert history records
            if (!historySObjectList.isEmpty()) {
                Database.insert(historySObjectList, false);
                System.debug('Inserted ' + historySObjectList.size() + ' history records');
            }
            
        } catch (Exception e) {
            System.debug('Error in getHistoryFieldMapping: ' + e.getMessage());
            ExceptionUtil.insertException(e);
        }
    }
    
    /**
     * @description Retrieves paginated history records using Apex Cursor
     * Cursor-based pagination is more efficient for large datasets than OFFSET/LIMIT
     * Memory usage remains constant regardless of pagination depth
     * 
     * @param recId The record ID to retrieve history for
     * @param limitSize Number of records to fetch per page
     * @param offsetSize Starting position for pagination (0-based)
     * @return List of History_Object__c records for the current page
     * @throws IllegalArgumentException if parameters are null
     */
    @AuraEnabled(cacheable=true)
    public static List<History_Object__c> sendHistoryFieldMappingToUI(
        Id recId, 
        Integer limitSize, 
        Integer offsetSize
    ) {
        // Input validation
        if (recId == null) {
            throw new IllegalArgumentException('Record ID cannot be null');
        }
        if (limitSize == null || limitSize <= 0) {
            throw new IllegalArgumentException('Limit size must be a positive integer');
        }
        if (offsetSize == null || offsetSize < 0) {
            throw new IllegalArgumentException('Offset size cannot be negative');
        }
        
        List<History_Object__c> result = new List<History_Object__c>();
        
        try {
            System.debug('Fetching history - RecId: ' + recId + ', Limit: ' + limitSize + ', Offset: ' + offsetSize);
            
            // Build dynamic query for cursor
            String query = 'SELECT Id, Created_Date__c, Field_Name__c, Owner__c, Old_Value__c, New_Value__c ' +
                          'FROM History_Object__c ' +
                          'WHERE Record_Id__c = :recId ' +
                          'ORDER BY Created_Date__c DESC';
            
            // Initialize cursor with query
            Database.Cursor cursor = Database.getCursor(query);
            
            // Move cursor to offset position for efficient pagination
            if (offsetSize > 0) {
                cursor.moveTo(offsetSize);
                System.debug('Cursor moved to position: ' + offsetSize);
            }
            
            // Fetch records from cursor starting at offset
            result = cursor.fetch(limitSize);
            
            System.debug('Fetched ' + result.size() + ' records from cursor');
            
        } catch (Exception e) {
            System.debug('Error fetching history records: ' + e.getMessage());
            ExceptionUtil.insertException(e);
            throw new AuraHandledException(e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Gets total count of history records for a given record ID
     * Used by LWC to determine pagination state and enable/disable navigation buttons
     * Uses aggregate COUNT() query for optimal performance
     * 
     * @param recId The record ID to get count for
     * @return Total number of history records for the specified record
     * @throws IllegalArgumentException if recId is null
     */
    @AuraEnabled(cacheable=true)
    public static Integer getHistoryRecordCount(Id recId) {
        if (recId == null) {
            throw new IllegalArgumentException('Record ID cannot be null');
        }
        
        try {
            Integer recordCount = [
                SELECT COUNT() 
                FROM History_Object__c 
                WHERE Record_Id__c = :recId
            ];
            
            System.debug('Total history records for ' + recId + ': ' + recordCount);
            return recordCount;
            
        } catch (Exception e) {
            System.debug('Error getting record count: ' + e.getMessage());
            ExceptionUtil.insertException(e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description Gets the SObject type name for a given record ID
     * @param recordId The record ID to get the object name for
     * @return The API name of the object (e.g., 'Account', 'Contact')
     */
    @AuraEnabled(cacheable=true)
    public static String getObjectName(Id recordId) {
        if (recordId == null) {
            throw new IllegalArgumentException('Record ID cannot be null');
        }
        return recordId.getSObjectType().getDescribe().getName();
    }
}
