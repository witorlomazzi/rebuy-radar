import { LightningElement, wire } from 'lwc';
import getRadar from '@salesforce/apex/RebuyRadarController.getRadar';
import getSummary from '@salesforce/apex/RebuyRadarController.getSummary';

const COLUMNS = [
    {
        label: 'Conta',
        fieldName: 'accountUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'accountName' }, target: '_self' }
    },
    { label: 'Nível', fieldName: 'riskLabel', type: 'text', initialWidth: 110 },
    { label: 'Score', fieldName: 'riskScore', type: 'number', initialWidth: 90 },
    { label: 'Dias em atraso', fieldName: 'daysOverdue', type: 'number', initialWidth: 130 },
    {
        label: 'Valor em risco',
        fieldName: 'valueAtRisk',
        type: 'currency',
        typeAttributes: { currencyCode: 'BRL' }
    },
    { label: 'Última compra', fieldName: 'lastPurchase', type: 'date-local' },
    { label: 'Próxima esperada', fieldName: 'expectedNext', type: 'date-local' }
];

const RISK_LABELS = {
    Critico: 'Crítico',
    Risco: 'Risco',
    Atencao: 'Atenção',
    Em_dia: 'Em dia'
};

export default class RebuyRadar extends LightningElement {
    columns = COLUMNS;
    level = '';
    rows = [];
    summary;
    error;

    filterOptions = [
        { label: 'Todos os níveis', value: '' },
        { label: 'Crítico', value: 'Critico' },
        { label: 'Risco', value: 'Risco' },
        { label: 'Atenção', value: 'Atencao' },
        { label: 'Em dia', value: 'Em_dia' }
    ];

    @wire(getSummary)
    wiredSummary({ data, error }) {
        if (data) {
            this.summary = data;
        } else if (error) {
            this.error = this.readError(error);
        }
    }

    @wire(getRadar, { riskLevel: '$level' })
    wiredRadar({ data, error }) {
        if (data) {
            this.error = undefined;
            this.rows = data.map((p) => ({
                id: p.Id,
                accountUrl: '/' + p.Account__c,
                accountName: p.Account__r ? p.Account__r.Name : '',
                riskLabel: RISK_LABELS[p.Risk_Level__c] || p.Risk_Level__c,
                riskScore: p.Risk_Score__c,
                daysOverdue: p.Days_Overdue__c,
                valueAtRisk: p.Value_At_Risk__c,
                lastPurchase: p.Last_Purchase_Date__c,
                expectedNext: p.Expected_Next_Purchase_Date__c
            }));
        } else if (error) {
            this.error = this.readError(error);
            this.rows = [];
        }
    }

    handleFilterChange(event) {
        this.level = event.detail.value;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get showEmptyState() {
        return !this.error && this.rows.length === 0;
    }

    readError(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : 'Não foi possível carregar o radar.';
    }
}
