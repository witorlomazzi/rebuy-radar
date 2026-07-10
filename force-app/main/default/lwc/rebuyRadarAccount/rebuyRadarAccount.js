import { LightningElement, api, wire } from 'lwc';
import getForAccount from '@salesforce/apex/RebuyRadarController.getForAccount';

const RISK_META = {
    Critico: { label: 'Crítico', theme: 'critico', badge: 'slds-theme_error' },
    Risco: { label: 'Risco', theme: 'risco', badge: 'slds-theme_warning' },
    Atencao: { label: 'Atenção', theme: 'atencao', badge: 'slds-theme_warning' },
    Em_dia: { label: 'Em dia', theme: 'emdia', badge: 'slds-theme_success' }
};

export default class RebuyRadarAccount extends LightningElement {
    @api recordId;

    pattern;
    error;
    loaded = false;

    @wire(getForAccount, { accountId: '$recordId' })
    wiredPattern({ data, error }) {
        this.loaded = true;
        if (data) {
            this.error = undefined;
            this.pattern = data;
        } else if (error) {
            this.pattern = undefined;
            this.error = this.readError(error);
        } else {
            // conta sem snapshot: data vem null, sem erro
            this.pattern = undefined;
            this.error = undefined;
        }
    }

    get hasPattern() {
        return this.loaded && !!this.pattern && !this.error;
    }

    get showEmptyState() {
        return this.loaded && !this.pattern && !this.error;
    }

    get riskMeta() {
        return (this.pattern && RISK_META[this.pattern.Risk_Level__c]) || {
            label: this.pattern ? this.pattern.Risk_Level__c : '',
            theme: 'emdia',
            badge: 'slds-theme_success'
        };
    }

    get riskLabel() {
        return this.riskMeta.label;
    }

    get badgeClass() {
        return 'slds-badge risk-badge ' + this.riskMeta.badge;
    }

    get cardAccentClass() {
        return 'radar-accent accent-' + this.riskMeta.theme;
    }

    get riskScore() {
        return this.pattern ? this.pattern.Risk_Score__c : null;
    }

    get daysOverdue() {
        return this.pattern ? this.pattern.Days_Overdue__c : null;
    }

    get valueAtRisk() {
        return this.pattern ? this.pattern.Value_At_Risk__c : null;
    }

    get lastPurchase() {
        return this.pattern ? this.pattern.Last_Purchase_Date__c : null;
    }

    get expectedNext() {
        return this.pattern ? this.pattern.Expected_Next_Purchase_Date__c : null;
    }

    get averageInterval() {
        return this.pattern ? this.pattern.Average_Interval_Days__c : null;
    }

    get averageOrderValue() {
        return this.pattern ? this.pattern.Average_Order_Value__c : null;
    }

    get purchasesAnalyzed() {
        return this.pattern ? this.pattern.Purchases_Analyzed__c : null;
    }

    readError(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : 'Não foi possível carregar o radar desta conta.';
    }
}
