public class SobjectFieldHistoryController{
    
    public static Void getHistoryFieldMapping(List<Sobject> newList, Map<Id,Sobject> OldList){
        if(newList == null || newList.isEmpty()) return;
        try{
            List<History_Object__c> historySObjectList = new List<History_Object__c>();
             Schema.SObjectType objectType = newList[0].getSObjectType();
             String objectName = objectType.getDescribe().getName();
             Sobject_History_Fields_Tracking__mdt sobjectHistoryMetadata = [Select Field_Set__c,Object_Name__c From Sobject_History_Fields_Tracking__mdt 
                                                                                 Where Object_Name__c=: objectName Limit 1];
            Set<String> fieldSet = new Set<String>();
 
            if (String.isNotBlank(sobjectHistoryMetadata.Field_Set__c)) {
                for (String fieldName : sobjectHistoryMetadata.Field_Set__c.split(';')) {
                    fieldSet.add(fieldName.trim());
                }
            }
             Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
            for(sObject eachRec : newList){
                Id recordId = (Id)eachRec.get('Id');
                SObject oldRec = OldList.get(recordId);
                if (oldRec == null) continue;
                for(String eachField : fieldSet){
                    Object oldValObj = oldRec.get(eachField);
                    Object newValObj = eachRec.get(eachField);
                    String oldVal = String.valueOf(oldValObj);
                    String newVal = String.valueOf(newValObj);
                    if(oldVal!=newVal){
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
            if(!historySObjectList.isEmpty()){
                Database.insert(historySObjectList);
            }
            System.debug('History Object List' + historySObjectList);
        }catch(Exception e){
            ExceptionUtil.insertException(e);
        }
    }
    
    /**
     * Retrieves paginated history records using Apex Cursor for efficient memory management.
     * Cursor-based pagination is preferred for large datasets as it avoids loading all records.
     * 
     * @param recId The record ID to retrieve history for
     * @param limitSize Number of records per page
     * @param offsetSize Starting position for pagination
     * @return List of History_Object__c records for the current page
     */
    @AuraEnabled(cacheable=true)
    public static List<History_Object__c> sendHistoryFieldMappingToUI(Id recId, Integer limitSize, Integer offsetSize) {
        if (recId == null || limitSize == null || offsetSize == null) {
            throw new IllegalArgumentException('recId, limitSize, and offsetSize cannot be null');
        }
        
        System.debug('Record Id: ' + recId + ', Limit: ' + limitSize + ', Offset: ' + offsetSize);
        
        List<History_Object__c> result = new List<History_Object__c>();
        
        try {
            // Build dynamic query for cursor
            String query = 'SELECT Id, Created_Date__c, Field_Name__c, Owner__c, Old_Value__c, New_Value__c ' +
                          'FROM History_Object__c ' +
                          'WHERE Record_Id__c = :recId ' +
                          'ORDER BY Created_Date__c DESC';
            
            // Initialize cursor with dynamic query
            Database.Cursor cursor = Database.getCursor(query);
            
            // Move cursor to the offset position
            if (offsetSize > 0) {
                cursor.moveTo(offsetSize);
            }
            
            // Fetch records from cursor starting at offset
            result = cursor.fetch(limitSize);
            
            System.debug('Fetched ' + result.size() + ' records from cursor');
        } catch (Exception e) {
            System.debug('Error fetching history records: ' + e.getMessage());
            ExceptionUtil.insertException(e);
            throw e;
        }
        
        return result;
    }
    
    /**
     * Gets the total count of history records for a given record ID.
     * Used by LWC to determine if next/previous buttons should be enabled.
     * 
     * @param recId The record ID to get count for
     * @return Total number of history records
     */
    @AuraEnabled(cacheable=true)
    public static Integer getHistoryRecordCount(Id recId) {
        if (recId == null) {
            throw new IllegalArgumentException('recId cannot be null');
        }
        
        try {
            Integer recordCount = [SELECT COUNT() FROM History_Object__c WHERE Record_Id__c = :recId];
            System.debug('Total history records for ' + recId + ': ' + recordCount);
            return recordCount;
        } catch (Exception e) {
            System.debug('Error getting record count: ' + e.getMessage());
            ExceptionUtil.insertException(e);
            throw e;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getObjectName(Id recordId) {
        return recordId.getSObjectType().getDescribe().getName();
    }
}