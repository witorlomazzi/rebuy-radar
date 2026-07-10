import { createElement } from 'lwc';
import RebuyRadarAccount from 'c/rebuyRadarAccount';
import getForAccount from '@salesforce/apex/RebuyRadarController.getForAccount';

jest.mock(
    '@salesforce/apex/RebuyRadarController.getForAccount',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const PATTERN = {
    Id: 'a01000000000001',
    Account__c: '001000000000001',
    Account__r: { Name: 'Vetra Cliente A' },
    Risk_Level__c: 'Critico',
    Risk_Score__c: 100,
    Days_Overdue__c: 70,
    Value_At_Risk__c: 6000,
    Average_Interval_Days__c: 30,
    Average_Order_Value__c: 2000,
    Last_Purchase_Date__c: '2026-03-01',
    Expected_Next_Purchase_Date__c: '2026-03-31',
    Purchases_Analyzed__c: 5
};

describe('c-rebuy-radar-account', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function mount() {
        const element = createElement('c-rebuy-radar-account', { is: RebuyRadarAccount });
        element.recordId = '001000000000001';
        document.body.appendChild(element);
        return element;
    }

    it('renderiza as métricas e o badge de risco da conta', async () => {
        const element = mount();
        getForAccount.emit(PATTERN);
        await Promise.resolve();

        const badge = element.shadowRoot.querySelector('.risk-badge');
        expect(badge).not.toBeNull();
        expect(badge.textContent).toBe('Crítico');

        const accent = element.shadowRoot.querySelector('.radar-accent');
        expect(accent.className).toContain('accent-critico');

        const values = element.shadowRoot.querySelectorAll('lightning-formatted-number');
        expect(values.length).toBeGreaterThan(0);
        expect(values[0].value).toBe(100);
    });

    it('mostra estado vazio quando a conta não tem padrão', async () => {
        const element = mount();
        getForAccount.emit(null);
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('.risk-badge')).toBeNull();
        expect(element.shadowRoot.textContent).toContain('Sem padrão de recompra calculado');
    });

    it('mostra a mensagem de erro do servidor', async () => {
        const element = mount();
        getForAccount.error({ message: 'Sem acesso ao radar.' });
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Sem acesso ao radar.');
    });
});
