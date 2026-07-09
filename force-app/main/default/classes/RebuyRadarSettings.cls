/**
 * Acesso à configuração ativa do Rebuy Radar (Custom Metadata).
 * Padrão @TestVisible: CMDT não aceita DML em teste, então os testes injetam a configuração.
 */
public inherited sharing class RebuyRadarSettings {

    @TestVisible
    private static Rebuy_Radar_Setting__mdt testOverride;

    public static Rebuy_Radar_Setting__mdt getActive() {
        if (testOverride != null) {
            return testOverride;
        }
        for (Rebuy_Radar_Setting__mdt setting : Rebuy_Radar_Setting__mdt.getAll().values()) {
            if (setting.Is_Active__c) {
                return setting;
            }
        }
        throw new RebuyRadarException(
            'Nenhuma configuração ativa em Rebuy_Radar_Setting__mdt. Ative um registro no Setup.'
        );
    }

    public class RebuyRadarException extends Exception {}
}
