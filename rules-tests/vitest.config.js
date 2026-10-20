import { defineConfig } from 'vitest/config';

// Alle Testdateien teilen sich einen Emulator und leeren ihn vor jedem Test,
// deshalb laufen sie nacheinander.
export default defineConfig({
  test: { fileParallelism: false },
});
