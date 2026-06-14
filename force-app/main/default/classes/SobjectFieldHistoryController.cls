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
    
    @AuraEnabled(cacheable=true)
    public static List<History_Object__c> sendHistoryFieldMappingToUI(Id recId,Integer limitSize,Integer offsetSize){
        System.debug('Record Id'+recId);
        /*Database.Cursor cursor = Database.getCursor('Select Id,Created_Date__c,Field_Name__c,Owner__c,Old_Value__c,New_Value__c From History_Object__c Where Record_Id__c=: recId Order by Created_Date__c desc');
        List<History_Object__c> result = cursor.fetch(offSetRow,limitSize);
        System.debug(result);*/
        //return result;
        return [Select Id,Created_Date__c,Field_Name__c,Owner__c,Old_Value__c,New_Value__c From History_Object__c 
                Where Record_Id__c=: recId
               Order by Created_Date__c desc  LIMIT :limitSize
            OFFSET :offsetSize];
    }
    
    @AuraEnabled(cacheable=true)
    public static String getObjectName(Id recordId) {
        return recordId.getSObjectType().getDescribe().getName();
    }
}