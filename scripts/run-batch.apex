/**
 * Executa o RebuyPatternBatch manualmente.
 * Usar: sf apex run --file scripts/run-batch.apex -o witor-dev
 */
Database.executeBatch(new RebuyPatternBatch(), 200);
System.debug('✓ Batch iniciado (200 contas por chunk)');
