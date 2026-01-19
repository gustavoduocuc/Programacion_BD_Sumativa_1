SET SERVEROUTPUT ON

--------------------------------------------------------------------------------
-- SUMATIVA 1 - PRY2206
-- Profesor: Eithel Gonzalez Rojas
-- Alumno: Gustavo Dominguez
-- Bloque PL/SQL anónimo: genera nombre de usuario y clave para cada empleado
-- y lo guarda en USUARIO_CLAVE.
--------------------------------------------------------------------------------

-- BIND: fecha de proceso
VARIABLE b_fecha_proceso VARCHAR2(19)
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')
PRINT b_fecha_proceso

DECLARE
    ----------------------------------------------------------------------------
    -- Variables base
    ----------------------------------------------------------------------------
    v_id_emp           empleado.id_emp%TYPE;
    v_numrun           empleado.numrun_emp%TYPE;
    v_dvrun            empleado.dvrun_emp%TYPE;
    v_pnombre          empleado.pnombre_emp%TYPE;
    v_snombre          empleado.snombre_emp%TYPE;
    v_appaterno        empleado.appaterno_emp%TYPE;
    v_apmaterno        empleado.apmaterno_emp%TYPE;
    v_sueldo_base      empleado.sueldo_base%TYPE;
    v_fecha_nac        empleado.fecha_nac%TYPE;
    v_fecha_contrato   empleado.fecha_contrato%TYPE;
    v_estado_civil     estado_civil.nombre_estado_civil%TYPE;

    ----------------------------------------------------------------------------
    -- Variables de salida (tabla destino)
    ----------------------------------------------------------------------------
    v_nombre_empleado  usuario_clave.nombre_empleado%TYPE;
    v_nombre_usuario   usuario_clave.nombre_usuario%TYPE;
    v_clave_usuario    usuario_clave.clave_usuario%TYPE;

    ----------------------------------------------------------------------------
    -- Auxiliares (cálculos y armado en PL/SQL)
    ----------------------------------------------------------------------------
    v_fecha_proceso    DATE;            -- bind convertido a DATE 
    v_anos_trabajados  PLS_INTEGER := 0;
    v_largo_nombre     PLS_INTEGER := 0;

    v_run_txt          VARCHAR2(20);
    v_tercer_dig_run   CHAR(1);

    v_ultimo_dig_sueldo   CHAR(1);
    v_ult3_sueldo_menos1  PLS_INTEGER := 0;

    v_pref_estado      CHAR(1);
    v_3letras_nombre   VARCHAR2(3);

    v_apellido_2letras VARCHAR2(2);

    v_yyyy_nac_mas2    PLS_INTEGER := 0;
    v_mmYYYY           VARCHAR2(6);

    ----------------------------------------------------------------------------
    -- Control de transacción (commit solo si termina completo)
    ----------------------------------------------------------------------------
    v_total_emps       PLS_INTEGER := 0;
    v_procesados       PLS_INTEGER := 0;

BEGIN
    ----------------------------------------------------------------------------
    -- 1) Convirtiendo la fecha bind (texto) a DATE para usar funciones de fecha mas adelante
    ----------------------------------------------------------------------------
    -- Evitando meter fechas fijas: el bind viene cargado con SYSDATE.
    v_fecha_proceso := TO_DATE(:b_fecha_proceso, 'YYYY-MM-DD HH24:MI:SS');

    ----------------------------------------------------------------------------
    -- 2) Truncando USUARIO_CLAVE para poder correr el bloque todas las veces que sea necesario
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('>> Truncando USUARIO_CLAVE para partir limpio...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';

    ----------------------------------------------------------------------------
    -- 3) Se cuenta cuántos empleados existen realmente en el rango 100..320
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
      INTO v_total_emps
      FROM empleado
     WHERE id_emp BETWEEN 100 AND 320;

    DBMS_OUTPUT.PUT_LINE('>> Total empleados a procesar: ' || v_total_emps);
    DBMS_OUTPUT.PUT_LINE('>> Fecha de proceso: ' || TO_CHAR(v_fecha_proceso, 'DD-MM-YYYY'));

    ----------------------------------------------------------------------------
    -- 3) Se procesan uno por uno (en orden ascendente por id_emp)
    ----------------------------------------------------------------------------
    FOR i IN 100..320 LOOP
        BEGIN
            --------------------------------------------------------------------
            -- SQL: Obteniendo los datos del empleado y su estado civil.
            --      NOTA: usuario/clave NO se arman aquí (se arman abajo en PL/SQL).
            --------------------------------------------------------------------
            SELECT e.id_emp,
                   e.numrun_emp,
                   e.dvrun_emp,
                   e.pnombre_emp,
                   e.snombre_emp,
                   e.appaterno_emp,
                   e.apmaterno_emp,
                   e.sueldo_base,
                   e.fecha_nac,
                   e.fecha_contrato,
                   ec.nombre_estado_civil
              INTO v_id_emp,
                   v_numrun,
                   v_dvrun,
                   v_pnombre,
                   v_snombre,
                   v_appaterno,
                   v_apmaterno,
                   v_sueldo_base,
                   v_fecha_nac,
                   v_fecha_contrato,
                   v_estado_civil
              FROM empleado e
              JOIN estado_civil ec
                ON ec.id_estado_civil = e.id_estado_civil
             WHERE e.id_emp = i;

            --------------------------------------------------------------------
            -- PL/SQL: Armando nombre completo simple para guardar
            --------------------------------------------------------------------
            v_nombre_empleado := TRIM(v_pnombre || ' ' || v_snombre || ' ' || v_appaterno || ' ' || v_apmaterno);

            --------------------------------------------------------------------
            -- PL/SQL: Años trabajados (entero)
            --------------------------------------------------------------------
            v_anos_trabajados := TRUNC(MONTHS_BETWEEN(v_fecha_proceso, v_fecha_contrato) / 12);
            IF v_anos_trabajados < 0 THEN
                v_anos_trabajados := 0;
            END IF;

            --------------------------------------------------------------------
            -- PL/SQL: Partes del NOMBRE_USUARIO
            --------------------------------------------------------------------
            v_pref_estado := LOWER(SUBSTR(TRIM(v_estado_civil), 1, 1)); -- 1ra letra del estado civil
            v_3letras_nombre := UPPER(SUBSTR(TRIM(v_pnombre), 1, 3));   -- 3 primeras del nombre
            v_largo_nombre := LENGTH(TRIM(v_pnombre));                 -- largo del nombre

            -- último dígito del sueldo
            v_ultimo_dig_sueldo := TO_CHAR(MOD(v_sueldo_base, 10));

            -- MMYYYY a partir de la fecha de proceso
            v_mmYYYY := TO_CHAR(v_fecha_proceso, 'MMYYYY');

            -- Nombre usuario = estado + 3letras + largo + * + ultDigSueldo + DV + años + (X si <10)
            v_nombre_usuario :=
                v_pref_estado ||
                v_3letras_nombre ||
                v_largo_nombre ||
                '*' ||
                v_ultimo_dig_sueldo ||
                v_dvrun ||
                v_anos_trabajados ||
                CASE WHEN v_anos_trabajados < 10 THEN 'X' ELSE '' END;

            --------------------------------------------------------------------
            -- PL/SQL: Partes de la CLAVE
            --------------------------------------------------------------------
            -- 3er dígito del RUN
            v_run_txt := TO_CHAR(v_numrun);
            -- Validación simple por seguridad: si el rut no tiene al menos 3 dígitos, no se puede cumplir el requisito
            IF LENGTH(v_run_txt) < 3 THEN
              RAISE_APPLICATION_ERROR(-20001, 'RUN inválido (menos de 3 dígitos) para empleado ' || v_id_emp);
            END IF;
            v_tercer_dig_run := SUBSTR(v_run_txt, 3, 1);

            -- Año nacimiento + 2
            v_yyyy_nac_mas2 := EXTRACT(YEAR FROM v_fecha_nac) + 2;
            
            -- Últimos 3 dígitos del sueldo - 1 (entero y sin negativos)
            v_ult3_sueldo_menos1 := MOD(v_sueldo_base, 1000) - 1;
            IF v_ult3_sueldo_menos1 < 0 THEN
                v_ult3_sueldo_menos1 := 0;
            END IF;
        
            --------------------------------------------------------------------
            -- PL/SQL: 2 letras del apellido paterno según estado civil
            -- Logica especial para apellidos muy cortos (para que nunca se caiga)
            --------------------------------------------------------------------
            IF v_appaterno IS NULL THEN
                v_appaterno := 'XX';
            END IF;

            IF LENGTH(TRIM(v_appaterno)) < 2 THEN
                v_appaterno := RPAD(TRIM(v_appaterno), 2, 'X');
            END IF;

            IF UPPER(TRIM(v_estado_civil)) IN ('CASADO', 'ACUERDO DE UNION CIVIL') THEN
                -- casado / AUC: 2 primeras letras
                v_apellido_2letras := LOWER(SUBSTR(TRIM(v_appaterno), 1, 2));

            ELSIF UPPER(TRIM(v_estado_civil)) IN ('DIVORCIADO', 'SOLTERO') THEN
                -- divorciado / soltero: primera y última
                v_apellido_2letras := LOWER(
                    SUBSTR(TRIM(v_appaterno), 1, 1) ||
                    SUBSTR(TRIM(v_appaterno), LENGTH(TRIM(v_appaterno)), 1)
                );

            ELSIF UPPER(TRIM(v_estado_civil)) = 'VIUDO' THEN
                -- viudo: antepenúltima y penúltima
                v_apellido_2letras := LOWER(SUBSTR(TRIM(v_appaterno), LENGTH(TRIM(v_appaterno)) - 2, 2));

            ELSIF UPPER(TRIM(v_estado_civil)) = 'SEPARADO' THEN
                -- separado: 2 últimas
                v_apellido_2letras := LOWER(SUBSTR(TRIM(v_appaterno), LENGTH(TRIM(v_appaterno)) - 1, 2));

            ELSE
                -- por si llega un estado civil distinto
                v_apellido_2letras := LOWER(SUBSTR(TRIM(v_appaterno), 1, 2));
            END IF;

            -- CLAVE = 3er dig RUN + (año nac +2) + (ult3 sueldo -1) + 2 letras apellido + id_emp + MMYYYY
            v_clave_usuario :=
                v_tercer_dig_run ||
                v_yyyy_nac_mas2 ||
                LPAD(TO_CHAR(v_ult3_sueldo_menos1), 3, '0') ||
                v_apellido_2letras ||
                v_id_emp ||
                v_mmYYYY;

            --------------------------------------------------------------------
            -- SQL: Insert final a USUARIO_CLAVE
            --------------------------------------------------------------------
            INSERT INTO usuario_clave
                (id_emp, numrun_emp, dvrun_emp, nombre_empleado, nombre_usuario, clave_usuario)
            VALUES
                (v_id_emp, v_numrun, v_dvrun, v_nombre_empleado, v_nombre_usuario, v_clave_usuario);

            v_procesados := v_procesados + 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Si no existe ese id en el rango, se salta
                NULL;
            WHEN OTHERS THEN
                -- Si algo realmente falla, que se note y no haga commit a medias
                RAISE;
        END;
    END LOOP;

    ----------------------------------------------------------------------------
    -- 5) Confirmación final: COMMIT solo si se logra procesar el total esperado
    ----------------------------------------------------------------------------
    IF v_procesados = v_total_emps THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('>> Listo: ' || v_procesados || '/' || v_total_emps || ' empleados. COMMIT aplicado.');
        DBMS_OUTPUT.PUT_LINE('>> Para revisar el resultado: SELECT * FROM USUARIO_CLAVE ORDER BY ID_EMP;');
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('>> Algo no cuadra: ' || v_procesados || '/' || v_total_emps || '. Hice ROLLBACK.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('>> Error: ' || SQLERRM);
END;
/