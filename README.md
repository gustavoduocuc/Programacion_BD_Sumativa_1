### [SUMATIVA 1] – Bloque PL/SQL de generación de credenciales

- Implementado bloque PL/SQL anónimo para generar usuario y clave por empleado según reglas de negocio.
- Uso de variable bind para fecha de proceso, evitando fechas fijas.
- Procesamiento completo de empleados (id_emp 100–320) con control de iteraciones.
- Cálculos realizados íntegramente en PL/SQL, sin lógica en sentencias SELECT.
- Manejo de reglas especiales según estado civil y validaciones de datos.
- Truncado de tabla `USUARIO_CLAVE` mediante SQL dinámico para ejecución repetible.
- Control de transacciones con COMMIT/ROLLBACK condicionado al procesamiento total.
- Documentación detallada de sentencias SQL y PL/SQL para facilitar comprensión y mantenimiento.
