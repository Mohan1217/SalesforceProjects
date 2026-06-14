/**
 * @description LWC component for displaying custom field history with pagination
 * Implements Apex Cursor-based pagination for efficient large dataset handling
 */
import { LightningElement, api, track, wire } from 'lwc';
import getFieldsData from '@salesforce/apex/SobjectFieldHistoryController.sendHistoryFieldMappingToUI';
import getObjectName from '@salesforce/apex/SobjectFieldHistoryController.getObjectName';
import getHistoryRecordCount from '@salesforce/apex/SobjectFieldHistoryController.getHistoryRecordCount';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';

// Column configuration for datatable
const COLUMNS = [
    {
        label: 'Date',
        fieldName: 'Created_Date__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Field',
        fieldName: 'Field_Name__c',
        type: 'text'
    },
    {
        label: 'Owner',
        fieldName: 'Owner__c',
        type: 'text'
    },
    {
        label: 'Original Value',
        fieldName: 'Old_Value__c',
        type: 'text'
    },
    {
        label: 'New Value',
        fieldName: 'New_Value__c',
        type: 'text'
    }
];

export default class CustomHistory extends LightningElement {
    // Public properties
    @api recordId;

    // Private tracked properties
    @track objectdata = [];
    @track totalRecordCount = 0;
    @track isLoading = false;
    @track error = null;

    // Wire result handlers
    wiredHistoryResult;
    wiredCountResult;
    wiredObjectNameResult;
    wiredObjectInfoResult;

    // Configuration properties
    rowLimit = 10;
    rowOffset = 0;
    currentPage = 1;
    columns = COLUMNS;

    // UI display properties
    objectApiName;
    objectLabel;

    /**
     * @description Getter to check if we're on the first page
     * @return true if offset is 0, false otherwise
     */
    get isFirstPage() {
        return this.rowOffset === 0;
    }

    /**
     * @description Getter to disable "Next" button based on total record count
     * Button is disabled when we've reached or exceeded the last page
     * @return true if next button should be disabled
     */
    get isNextDisabled() {
        return (this.rowOffset + this.rowLimit) >= this.totalRecordCount;
    }

    /**
     * @description Getter for current page record count
     * @return Number of records on current page
     */
    get recordCount() {
        return this.objectdata ? this.objectdata.length : 0;
    }

    /**
     * @description Getter for pagination info text (e.g., "1 - 10 of 45")
     * Shows which records are currently displayed and total available
     * @return Formatted pagination string
     */
    get paginationInfo() {
        if (this.totalRecordCount === 0) {
            return 'No records';
        }

        const startRecord = this.rowOffset + 1;
        const endRecord = Math.min(this.rowOffset + this.rowLimit, this.totalRecordCount);

        return `${startRecord} - ${endRecord} of ${this.totalRecordCount}`;
    }

    /**
     * @description Wire service to fetch paginated history records using Apex Cursor
     * Reactively updates when recordId, rowLimit, or rowOffset changes
     * Uses cursor-based pagination for efficient memory usage
     */
    @wire(getFieldsData, {
        recId: '$recordId',
        limitSize: '$rowLimit',
        offsetSize: '$rowOffset'
    })
    wiredContacts(result) {
        this.wiredHistoryResult = result;

        if (result.data) {
            this.objectdata = result.data;
            this.error = undefined;
            console.log('History data loaded. Records:', this.objectdata.length);
        } else if (result.error) {
            this.error = result.error;
            this.objectdata = [];
            console.error('Error loading history records:', result.error);
        }
    }

    /**
     * @description Wire service to fetch total history record count
     * Used to determine pagination state and button availability
     */
    @wire(getHistoryRecordCount, { recId: '$recordId' })
    wiredRecordCount(result) {
        this.wiredCountResult = result;

        if (result.data) {
            this.totalRecordCount = result.data;
            console.log('Total history records:', this.totalRecordCount);
        } else if (result.error) {
            console.error('Error getting record count:', result.error);
            this.totalRecordCount = 0;
        }
    }

    /**
     * @description Wire service to fetch SObject API name
     * Used to get the object type for the record being viewed
     */
    @wire(getObjectName, { recordId: '$recordId' })
    wiredObjectName(result) {
        this.wiredObjectNameResult = result;

        if (result.data) {
            this.objectApiName = result.data;
            console.log('Object API Name:', this.objectApiName);
        } else if (result.error) {
            console.error('Error fetching object name:', result.error);
        }
    }

    /**
     * @description Wire service to fetch SObject metadata (label, icon, etc.)
     * Depends on objectApiName being populated first
     */
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo(result) {
        this.wiredObjectInfoResult = result;

        if (result.data) {
            this.objectLabel = result.data.label;
            console.log('Object Label:', this.objectLabel);
        } else if (result.error) {
            console.error('Error fetching object info:', result.error);
        }
    }

    /**
     * @description Handles refresh button click
     * Refreshes both history data and record count
     */
    async handleRefresh() {
        console.log('Refreshing history data');
        this.isLoading = true;

        try {
            // Refresh both wired results to get latest data
            await refreshApex(this.wiredHistoryResult);
            await refreshApex(this.wiredCountResult);
            console.log('History data refreshed successfully');
        } catch (error) {
            console.error('Error during refresh:', error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handles previous page button click
     * Moves to previous page if not on first page
     */
    handlePrevious() {
        console.log('Previous button clicked. Current offset:', this.rowOffset);

        if (this.rowOffset >= this.rowLimit) {
            this.rowOffset -= this.rowLimit;
            this.currentPage -= 1;
            console.log('Navigated to page:', this.currentPage, 'Offset:', this.rowOffset);
        }
    }

    /**
     * @description Handles next page button click
     * Moves to next page if not on last page (checked against total record count)
     */
    handleNext() {
        console.log('Next button clicked. Current offset:', this.rowOffset);

        const nextOffset = this.rowOffset + this.rowLimit;

        // Verify we have more records to display
        if (nextOffset < this.totalRecordCount) {
            this.rowOffset = nextOffset;
            this.currentPage += 1;
            console.log('Navigated to page:', this.currentPage, 'Offset:', this.rowOffset);
        } else {
            console.log('Already on last page');
        }
    }
}
