import { createElement } from 'lwc';
import RebuyRadar from 'c/rebuyRadar';
import getRadar from '@salesforce/apex/RebuyRadarController.getRadar';
import getSummary from '@salesforce/apex/RebuyRadarController.getSummary';

jest.mock(
    '@salesforce/apex/RebuyRadarController.getRadar',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/RebuyRadarController.getSummary',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const RADAR = [
    {
        Id: 'a01000000000001',
        Account__c: '001000000000001',
        Account__r: { Name: 'Vetra Cliente A' },
        Risk_Level__c: 'Critico',
        Risk_Score__c: 100,
        Days_Overdue__c: 70,
        Value_At_Risk__c: 6000,
        Last_Purchase_Date__c: '2026-03-01',
        Expected_Next_Purchase_Date__c: '2026-03-31'
    },
    {
        Id: 'a01000000000002',
        Account__c: '001000000000002',
        Account__r: { Name: 'Vetra Cliente B' },
        Risk_Level__c: 'Atencao',
        Risk_Score__c: 65,
        Days_Overdue__c: 12,
        Value_At_Risk__c: 1500,
        Last_Purchase_Date__c: '2026-06-01',
        Expected_Next_Purchase_Date__c: '2026-07-01'
    }
];

const SUMMARY = { total: 2, critico: 1, risco: 0, atencao: 1, emDia: 0, totalValueAtRisk: 7500 };

describe('c-rebuy-radar', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function mount() {
        const element = createElement('c-rebuy-radar', { is: RebuyRadar });
        document.body.appendChild(element);
        return element;
    }

    it('renderiza as linhas do radar achatadas para a datatable', async () => {
        const element = mount();
        getRadar.emit(RADAR);
        await Promise.resolve();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();
        expect(table.data).toHaveLength(2);
        expect(table.data[0].accountName).toBe('Vetra Cliente A');
        expect(table.data[0].accountUrl).toBe('/001000000000001');
        expect(table.data[0].riskLabel).toBe('Crítico');
    });

    it('renderiza o resumo com contagens e total em risco', async () => {
        const element = mount();
        getSummary.emit(SUMMARY);
        await Promise.resolve();

        const tiles = element.shadowRoot.querySelectorAll('.tile');
        expect(tiles).toHaveLength(5);
        expect(element.shadowRoot.querySelector('.tile-critico .tile-num').textContent).toBe('1');
    });

    it('mostra estado vazio quando não há linhas', async () => {
        const element = mount();
        getRadar.emit([]);
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        expect(element.shadowRoot.textContent).toContain('Nenhuma conta no radar');
    });

    it('mostra a mensagem de erro do servidor', async () => {
        const element = mount();
        getRadar.error({ message: 'Sem acesso ao radar.' });
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Sem acesso ao radar.');
    });
});
