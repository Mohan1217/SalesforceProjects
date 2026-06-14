import { LightningElement, api, track, wire } from 'lwc';
import getFieldsData from '@salesforce/apex/SobjectFieldHistoryController.sendHistoryFieldMappingToUI';
import getObjectName from '@salesforce/apex/SobjectFieldHistoryController.getObjectName';
import getHistoryRecordCount from '@salesforce/apex/SobjectFieldHistoryController.getHistoryRecordCount';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
//import { NavigationMixin } from 'lightning/navigation';

const COLUMNS = [
    { label: 'Date', fieldName: 'Created_Date__c', type: 'text', sortable: true },
    { label: 'Field', fieldName: 'Field_Name__c', type: 'text' },
    { label: 'Owner', fieldName: 'Owner__c', type: 'text' },
    { label: 'Original Value', fieldName: 'Old_Value__c', type: 'text' },
    { label: 'New Value', fieldName: 'New_Value__c', type: 'text' }
];

 
export default class CustomHistory extends LightningElement {
    @api recordId;
 
    columns = COLUMNS;
    @track objectdata = [];
    @track totalRecordCount = 0;
    
    wiredHistoryResult;
    wiredCountResult;
    error;
    isLoading = false;
    rowLimit = 10;
    rowOffset = 0;
    currentPage = 1;
 
    objectApiName;
    objectLabel;
    //iconName;

    get isFirstPage() {
        return this.rowOffset === 0;
    }

    get isNextDisabled() {
        return (this.rowOffset + this.rowLimit) >= this.totalRecordCount;
    }

    get recordCount() {
        return this.objectdata ? this.objectdata.length : 0;
    }

    get paginationInfo() {
        const startRecord = this.totalRecordCount === 0 ? 0 : this.rowOffset + 1;
        const endRecord = Math.min(this.rowOffset + this.rowLimit, this.totalRecordCount);
        return `${startRecord} - ${endRecord} of ${this.totalRecordCount}`;
    }
 
 
    @wire(getFieldsData, { recId: '$recordId', limitSize: '$rowLimit', offsetSize: '$rowOffset' })
    wiredContacts(result) {
        this.wiredHistoryResult = result;
 
        if (result.data) {
            this.objectdata = result.data;
            console.log('History data loaded:', this.objectdata);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.objectdata = [];
            console.error('Error loading history:', this.error);
        }
    }

    @wire(getHistoryRecordCount, { recId: '$recordId' })
    wiredRecordCount(result) {
        this.wiredCountResult = result;
        
        if (result.data) {
            this.totalRecordCount = result.data;
            console.log('Total record count:', this.totalRecordCount);
        } else if (result.error) {
            console.error('Error getting record count:', result.error);
            this.totalRecordCount = 0;
        }
    }
 
    async handleRefresh() {
        console.log('Refreshing history data');
        this.isLoading = true;
        try {
            // Refresh both the history data and count
            await refreshApex(this.wiredHistoryResult);
            await refreshApex(this.wiredCountResult);
        } catch (error) {
            console.error('Error during refresh:', error);
        } finally {
            this.isLoading = false;
        }
    }
 
    @wire(getObjectName, { recordId: '$recordId' })
    wiredObjectName({ data }) {
        if (data) {
            this.objectApiName = data;
            console.log('Object API Name:', this.objectApiName);
        }
    }
 
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ data }) {
        if (data) {
            console.log('Object Label:', data.label);
            this.objectLabel = data.label;
            //this.iconName = data.themeInfo?.iconUrl || data.iconName;
        }
    }

    handlePrevious() {
        console.log('Previous clicked. Current offset:', this.rowOffset);
        if (this.rowOffset >= this.rowLimit) {
            this.rowOffset -= this.rowLimit;
            this.currentPage -= 1;
            console.log('New offset:', this.rowOffset, 'Page:', this.currentPage);
        }
    }

    handleNext() {
        console.log('Next clicked. Current offset:', this.rowOffset);
        if ((this.rowOffset + this.rowLimit) < this.totalRecordCount) {
            this.rowOffset += this.rowLimit;
            this.currentPage += 1;
            console.log('New offset:', this.rowOffset, 'Page:', this.currentPage);
        }
    }
}