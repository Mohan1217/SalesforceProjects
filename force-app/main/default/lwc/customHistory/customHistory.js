import { LightningElement, api, track, wire } from 'lwc';
import getFieldsData from '@salesforce/apex/SobjectFieldHistoryController.sendHistoryFieldMappingToUI';
import getObjectName from '@salesforce/apex/SobjectFieldHistoryController.getObjectName';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
//import { NavigationMixin } from 'lightning/navigation';

const COLUMNS = [
    { label: 'Date', fieldName: 'Created_Date__c' },
    { label: 'Field', fieldName: 'Field_Name__c' },
    { label: 'Owner', fieldName: 'Owner__c' },
    { label: 'Original Value', fieldName: 'Old_Value__c' },
    { label: 'New Value', fieldName: 'New_Value__c' }
];

 
export default class CustomHistory extends LightningElement {
    @api recordId;
 
    columns = COLUMNS;
    @track objectdata = [];
    wiredHistoryResult;
    error;
    isLoading = false;
    rowLimit = 10;
    rowOffset = 0;
 
    objectApiName;
    objectLabel;
    //iconName;

    get isFirstPage() {
        return this.rowOffset === 0;
    }

    get isNextDisabled() {
        return this.objectdata.length < this.rowLimit;
    }

    get recordCount() {
        return this.objectdata ? this.objectdata.length : 0;
    }
 
 
    @wire(getFieldsData, { recId: '$recordId',limitSize: '$rowLimit',offsetSize: '$rowOffset'})
    wiredContacts(result) {
        this.wiredHistoryResult = result;
 
        if (result.data) {
            this.objectdata = result.data;
            console.log(this.objectdata);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.objectdata = [];
        }
    }
 
    async handleRefresh() {
        console.log('handle Refresh called');
        this.isLoading = true;
        try {
            await refreshApex(this.wiredHistoryResult);
        } finally {
            this.isLoading = false;
        }
    }
 
    @wire(getObjectName, { recordId: '$recordId' })
    wiredObjectName({ data }) {
        if (data) {
            this.objectApiName = data;
            console.log(this.objectApiName);
        }
    }
 
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ data }) {
        if (data) {
            console.log('Data Label'+data.label);
            this.objectLabel = data.label;
            //this.iconName = data.themeInfo?.iconUrl || data.iconName;
            console.log('Icon Name'+this.iconName);
        }
    }

    handlePrevious() {
        console.log('Previous clicked');
        if (this.rowOffset >= this.rowLimit) {
            this.rowOffset -= this.rowLimit;
        }
    }

    handleNext() {
        console.log('Next clicked');
        this.rowOffset += this.rowLimit;
    }
}